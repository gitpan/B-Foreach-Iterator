#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#ifndef gv_stashpvs
#define gv_stashpvs(name, flags) Perl_gv_stashpvn(aTHX_ STR_WITH_LEN(name), flags)
#endif

#ifndef CxLABEL
#define CxLABEL(cx) ((cx)->blk_loop.label)
#endif

#if PERL_BCDVERSION >= 0x5010000
#define cx_loop_op(cx) ( (OP*)((cx)->blk_loop.my_op) )
#else
#define cx_loop_op(cx) ( (OP*)((cx)->blk_loop.next_op->op_next) )
#endif

#define LoopIsReversed(cx) (cx_loop_op(cx)->op_private & OPpITER_REVERSED ? TRUE : FALSE)

#define PACKAGE "B::Foreach::Iterator"

#if 0
static PERL_CONTEXT*
my_uplevel_cx(pTHX_ PERL_CONTEXT* const cxstk, I32 const startingblock, I32 const cxtype){
	I32 i;
	for (i = startingblock; i >= 0; i--) {
		PERL_CONTEXT* const cx = &cxstk[i];
		if((I32)CxTYPE(cx) == cxtype){
			return cx;
		}
	}
	return NULL;
}
#endif

static PERL_CONTEXT*
my_find_cx(pTHX_ const OP* const loop_op){
	PERL_CONTEXT* const cxstk = cxstack;
	I32 i;
	for (i = cxstack_ix; i >= 0; i--) {
		if(CxTYPE(&cxstk[i]) == CXt_LOOP && cx_loop_op(&cxstk[i]) == loop_op){
			return &cxstk[i];
		}
	}

	Perl_croak(aTHX_ "Out of scope for the foreach iterator");
	return NULL;
}

static PERL_CONTEXT*
my_find_foreach(pTHX_ SV* const label){
	PERL_CONTEXT* const cxstk = cxstack;
	I32 i;
	const char* const label_pv = SvOK(label) ? SvPV_nolen_const(label) : NULL;

	for (i = cxstack_ix; i >= 0; i--) {
		PERL_CONTEXT* const cx = &cxstk[i];
		if(CxTYPE(cx) == CXt_LOOP && CxITERVAR(cx)){

			if(label_pv){
				if(CxLABEL(cx) && strEQ(CxLABEL(cx), label_pv)){
					return cx;
				}
			}
			else{
				return cx;
			}
		}
	}

	if(label_pv){
		Perl_croak(aTHX_ "No foreach loops found for %s", label_pv);
	}
	else{
		Perl_croak(aTHX_ "No foreach loops found");
	}
	return NULL; /* not reached */
}

typedef SV* SVREF;

MODULE = B::Foreach::Iterator	PACKAGE = B::Foreach::Iterator

PROTOTYPES: DISABLE

#define need_increment ix

SV*
iter(label = NULL)
PREINIT:
	PERL_CONTEXT* const cx = my_find_foreach(aTHX_ items == 1 ? ST(0) : &PL_sv_undef);
	HV* const stash        = gv_stashpvs(PACKAGE, TRUE);
	SV* const iterator     = newRV_noinc(newSViv(PTR2IV(cx_loop_op(cx))));
CODE:
	RETVAL = sv_bless(iterator, stash);
OUTPUT:
	RETVAL

SV*
next(SVREF iterator)
ALIAS:
	next = TRUE
	peek = FALSE
PREINIT:
	PERL_CONTEXT* cx;
	SV** itersvp;
CODE:
	RETVAL  = NULL;
	cx      = my_find_cx(aTHX_ (OP*)INT2PTR(SV*, SvIV(iterator)));
	itersvp = CxITERVAR(cx);

	/* see also pp_iter() in pp_hot.c */
	if (SvTYPE(cx->blk_loop.iterary) != SVt_PVAV) { /* foreach(min .. max) */

		if(cx->blk_loop.iterlval) { /* non-integer range (e.g. 'a' .. 'z') */
			SV* const cur = cx->blk_loop.iterlval;
			SV* const max = (SV*)cx->blk_loop.iterary;

			if (need_increment){
				SvREFCNT_dec(*itersvp);
				*itersvp = newSVsv(cur);
			}

			if (strNE(SvPV_nolen_const(cur), "0")){
				if(need_increment){
					if(sv_eq(cur, max)){
						sv_setiv(cur, 0);
					}
					else{
						sv_inc(cur);
					}
					RETVAL = *itersvp;
				}
				else{
					RETVAL = cur;
				}
			}
		}
		else { /* integer range */
			if (cx->blk_loop.iterix <= cx->blk_loop.itermax){
				RETVAL = newSViv(cx->blk_loop.iterix);
				sv_2mortal(RETVAL);
			}

			if (need_increment) cx->blk_loop.iterix++;
		}
	}
	else { /* foreach (@array) or foreach (expr) */
		AV* const av        = cx->blk_loop.iterary;
		bool const reversed = LoopIsReversed(cx);
		bool const in_range = reversed ? (--cx->blk_loop.iterix >= ( cx->blk_loop.itermax ) /* min */ )
		                               : (++cx->blk_loop.iterix <= ( av == PL_curstack ? cx->blk_oldsp : av_len(av)) /* max */ );

		if (in_range){
			if (SvMAGICAL(av) || AvREIFY(av)){
				SV** const svp = av_fetch(av, cx->blk_loop.iterix, FALSE);
				if(svp) RETVAL = *svp;
			}
			else{
				RETVAL = AvARRAY(av)[cx->blk_loop.iterix];
			}
		}

		if (!need_increment){
			reversed ? ++cx->blk_loop.iterix : --cx->blk_loop.iterix;
		}
	}

	ST(0) = RETVAL ? RETVAL : &PL_sv_undef;
	XSRETURN(1);


const char*
label(SVREF iterator)
PREINIT:
	const PERL_CONTEXT* cx;
CODE:
	cx     = my_find_cx(aTHX_ (OP*)INT2PTR(SV*, SvIV(iterator)));
	RETVAL = CxLABEL(cx); /* can be NULL */
OUTPUT:
	RETVAL
