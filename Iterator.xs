#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

static PERL_CONTEXT*
my_find_cx(pTHX_ PERL_CONTEXT* const cxstk, I32 const startingblock, I32 const cxtype){
	I32 i;
	for (i = startingblock; i >= 0; i--) {
		PERL_CONTEXT* const cx = &cxstk[i];
		if((I32)CxTYPE(cx) == cxtype){
			return cx;
		}
	}
	return NULL;
}

#if PERL_BCDVERSION >= 0x5010000
#define LoopIsReversed(cx) (cx->blk_loop.my_op->op_private & OPpITER_REVERSED ? TRUE : FALSE)
#else
#define LoopIsReversed(cx) (cx->blk_loop.next_op->op_next->op_private & OPpITER_REVERSED ? TRUE : FALSE)
#endif

MODULE = B::Foreach::Iterator	PACKAGE = B::Foreach::Iterator

PROTOTYPES: ENABLE

#define need_increment ix

SV*
iter_inc()
ALIAS:
	iter_inc  = TRUE
	iter_next = FALSE
PREINIT:
	PERL_CONTEXT* const cx = my_find_cx(aTHX_ cxstack, cxstack_ix, CXt_LOOP);
	SV** const itersvp     = cx ? CxITERVAR(cx) : NULL;
CODE:
	if (!itersvp) {
		Perl_croak(aTHX_ "No foreach loops found");
	}
	//op_dump(cx->blk_loop.my_op);
	//Perl_cx_dump(aTHX_ cx); sv_dump((SV*)cx->blk_loop.iterary); XSRETURN_EMPTY;

	RETVAL = NULL;

	/* see also pp_iter() in pp_hot.c */
	if (SvTYPE(cx->blk_loop.iterary) != SVt_PVAV) { /* foreach(min .. max) */

		if(cx->blk_loop.iterlval) { /* non-numeric range (e.g. 'a' .. 'z') */
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
		else { /* numeric range */
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
