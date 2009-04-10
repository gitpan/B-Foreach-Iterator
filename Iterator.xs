#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#ifndef gv_stashpvs
#define gv_stashpvs(name, flags) Perl_gv_stashpvn(aTHX_ STR_WITH_LEN(name), flags)
#endif

#ifndef newSV_type
#define newSV_type(t) my_newSV_type(aTHX_ t)
static SV*
my_newSV_type(pTHX_ svtype const svt){
	SV* const sv = newSV(0);
	sv_upgrade(sv, svt);
	return sv;
}
#endif

#ifndef CxLABEL
#define CxLABEL(cx) ((cx)->blk_loop.label)
#endif

#ifndef CxFOREACH
#define CxFOREACH(cx) (CxTYPE(cx) == CXt_LOOP && CxITERVAR(cx) != NULL)
#endif

#ifndef CxITERARY
#define CxITERARY(cx) ((cx)->blk_loop.iterary)
#endif

#ifndef CX_LOOP_NEXTOP_GET
#define CX_LOOP_NEXTOP_GET(cx) ((cx)->blk_loop.next_op)
#endif


#define LoopIsReversed(cx) (CX_LOOP_NEXTOP_GET(cx)->op_next->op_private & OPpITER_REVERSED ? TRUE : FALSE)


static PERL_CONTEXT*
my_find_cx(pTHX_ const OP* const loop_op){
	PERL_CONTEXT* const cxstk = cxstack;
	I32 i;
	for (i = cxstack_ix; i >= 0; i--) {
		PERL_CONTEXT* const cx = &cxstk[i];
		if(CxFOREACH(cx) && CX_LOOP_NEXTOP_GET(cx) == loop_op){
			return cx;
		}
	}

	Perl_croak(aTHX_ "Out of scope for the foreach iterator");
	return NULL;
}

static PERL_CONTEXT*
my_find_foreach(pTHX_ SV* const label){
	PERL_CONTEXT* const cxstk = cxstack;
	const char* const label_pv = SvOK(label) ? SvPV_nolen_const(label) : NULL;
	I32 i;

	for (i = cxstack_ix; i >= 0; i--) {
		PERL_CONTEXT* const cx = &cxstk[i];
		if(CxFOREACH(cx)){
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
		Perl_croak(aTHX_ "No foreach loops found for \"%s\"", label_pv);
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
	const PERL_CONTEXT* const cx = my_find_foreach(aTHX_ items == 1 ? ST(0) : &PL_sv_undef);
	SV* const iterator           = newSV_type(SVt_PVMG);
CODE:
	sv_setiv(iterator, PTR2IV(CX_LOOP_NEXTOP_GET(cx)));
	RETVAL = sv_bless(newRV_noinc(iterator), GvSTASH(CvGV(cv)));
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
	AV*  iterary;
CODE:
	RETVAL  = NULL;
	cx      = my_find_cx(aTHX_ INT2PTR(OP*, SvIV(iterator)));
	itersvp = CxITERVAR(cx);
	iterary = CxITERARY(cx);

	/* see also pp_iter() in pp_hot.c */
	if (SvTYPE(iterary) != SVt_PVAV) { /* foreach(min .. max) */

		if(cx->blk_loop.iterlval) { /* non-integer range (e.g. 'a' .. 'z') */
			SV* const cur = cx->blk_loop.iterlval;

			if (strNE(SvPV_nolen_const(cur), "0")){
				if(need_increment){
					SV* const max = (SV*)iterary;

					RETVAL = sv_newmortal();
					sv_setsv(RETVAL, cur);

					if(sv_eq(cur, max)){
						sv_setiv(cur, 0);
					}
					else{
						sv_inc(cur);
					}
				}
				else{
					RETVAL = cur;
				}
			}
		}
		else { /* integer range */
			if (cx->blk_loop.iterix <= cx->blk_loop.itermax){
				RETVAL = sv_newmortal();
				sv_setiv(RETVAL, cx->blk_loop.iterix);
			}

			if (need_increment) cx->blk_loop.iterix++;
		}
	}
	else { /* foreach (@array) or foreach (list) */
		bool const reversed = LoopIsReversed(cx);
		bool const in_range = reversed ? (--cx->blk_loop.iterix >= ( cx->blk_loop.itermax ) /* min */ )
		                               : (++cx->blk_loop.iterix <= ( iterary == PL_curstack ? cx->blk_oldsp : av_len(iterary)) /* max */ );

		if (in_range){
			if (SvMAGICAL(iterary) || AvREIFY(iterary)){
				SV** const svp = av_fetch(iterary, cx->blk_loop.iterix, FALSE);
				if(svp) RETVAL = *svp;
			}
			else{
				RETVAL = AvARRAY(iterary)[cx->blk_loop.iterix];
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
	cx     = my_find_cx(aTHX_ INT2PTR(OP*, SvIV(iterator)));
	RETVAL = CxLABEL(cx); /* can be NULL */
OUTPUT:
	RETVAL
