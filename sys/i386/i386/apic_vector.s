/*-
 * Copyright (c) 1989, 1990 William F. Jolitz.
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	from: vector.s, 386BSD 0.1 unknown origin
 * $FreeBSD$
 */

/*
 * Interrupt entry points for external interrupts triggered by I/O APICs
 * as well as IPI handlers.
 */

#include <machine/asmacros.h>
#include <machine/apicreg.h>
#include <machine/smptests.h>

#include "assym.s"

/*
 * Macros to create and destroy a trap frame.
 */
#define PUSH_FRAME							\
	pushl	$0 ;		/* dummy error code */			\
	pushl	$0 ;		/* dummy trap type */			\
	pushal ;		/* 8 ints */				\
	pushl	%ds ;		/* save data and extra segments ... */	\
	pushl	%es ;							\
	pushl	%fs

#define POP_FRAME							\
	popl	%fs ;							\
	popl	%es ;							\
	popl	%ds ;							\
	popal ;								\
	addl	$4+4,%esp

/*
 * I/O Interrupt Entry Point.  Rather than having one entry point for
 * each interrupt source, we use one entry point for each 32-bit word
 * in the ISR.  The handler determines the highest bit set in the ISR,
 * translates that into a vector, and passes the vector to the
 * lapic_handle_intr() function.
 */
#define	ISR_VEC(index, vec_name)					\
	.text ;								\
	SUPERALIGN_TEXT ;						\
IDTVEC(vec_name) ;							\
	PUSH_FRAME ;							\
	movl	$KDSEL, %eax ;	/* reload with kernel's data segment */	\
	movl	%eax, %ds ;						\
	movl	%eax, %es ;						\
	movl	$KPSEL, %eax ;	/* reload with per-CPU data segment */	\
	movl	%eax, %fs ;						\
	FAKE_MCOUNT(TF_EIP(%esp)) ;					\
	movl	lapic, %edx ;	/* pointer to local APIC */		\
	movl	LA_ISR + 16 * (index)(%edx), %eax ;	/* load ISR */	\
	bsrl	%eax, %eax ;	/* index of highset set bit in ISR */	\
	jz	2f ;							\
	addl	$(32 * index),%eax ;					\
1: ;									\
	pushl	%eax ;		/* pass the IRQ */			\
	call	lapic_handle_intr ;					\
	addl	$4, %esp ;	/* discard parameter */			\
	MEXITCOUNT ;							\
	jmp	doreti ;						\
2:	movl	$-1, %eax ;	/* send a vector of -1 */		\
	jmp	1b

/*
 * Handle "spurious INTerrupts".
 * Notes:
 *  This is different than the "spurious INTerrupt" generated by an
 *   8259 PIC for missing INTs.  See the APIC documentation for details.
 *  This routine should NOT do an 'EOI' cycle.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(spuriousint)

	/* No EOI cycle used here */

	iret

	ISR_VEC(1, apic_isr1)
	ISR_VEC(2, apic_isr2)
	ISR_VEC(3, apic_isr3)
	ISR_VEC(4, apic_isr4)
	ISR_VEC(5, apic_isr5)
	ISR_VEC(6, apic_isr6)
	ISR_VEC(7, apic_isr7)

/*
 * Local APIC periodic timer handler.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(timerint)
	PUSH_FRAME
	movl	$KDSEL, %eax	/* reload with kernel's data segment */
	movl	%eax, %ds
	movl	%eax, %es
	movl	$KPSEL, %eax
	movl	%eax, %fs

	movl	lapic, %edx
	movl	$0, LA_EOI(%edx)	/* End Of Interrupt to APIC */
	
	FAKE_MCOUNT(TF_EIP(%esp))

	pushl	$0		/* XXX convert trapframe to clockframe */
	call	lapic_handle_timer
	addl	$4, %esp	/* XXX convert clockframe to trapframe */
	MEXITCOUNT
	jmp	doreti

#ifdef SMP
/*
 * Global address space TLB shootdown.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(invltlb)
	pushl	%eax
	pushl	%ds
	movl	$KDSEL, %eax		/* Kernel data selector */
	movl	%eax, %ds

#if defined(COUNT_XINVLTLB_HITS) || defined(COUNT_IPIS)
	pushl	%fs
	movl	$KPSEL, %eax		/* Private space selector */
	movl	%eax, %fs
	movl	PCPU(CPUID), %eax
	popl	%fs
#ifdef COUNT_XINVLTLB_HITS
	incl	xhits_gbl(,%eax,4)
#endif
#ifdef COUNT_IPIS
	movl	ipi_invltlb_counts(,%eax,4),%eax
	incl	(%eax)
#endif
#endif

	movl	%cr3, %eax		/* invalidate the TLB */
	movl	%eax, %cr3

	movl	lapic, %eax
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */

	lock
	incl	smp_tlb_wait

	popl	%ds
	popl	%eax
	iret

/*
 * Single page TLB shootdown
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(invlpg)
	pushl	%eax
	pushl	%ds
	movl	$KDSEL, %eax		/* Kernel data selector */
	movl	%eax, %ds

#if defined(COUNT_XINVLTLB_HITS) || defined(COUNT_IPIS)
	pushl	%fs
	movl	$KPSEL, %eax		/* Private space selector */
	movl	%eax, %fs
	movl	PCPU(CPUID), %eax
	popl	%fs
#ifdef COUNT_XINVLTLB_HITS
	incl	xhits_pg(,%eax,4)
#endif
#ifdef COUNT_IPIS
	movl	ipi_invlpg_counts(,%eax,4),%eax
	incl	(%eax)
#endif
#endif

	movl	smp_tlb_addr1, %eax
	invlpg	(%eax)			/* invalidate single page */

	movl	lapic, %eax
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */

	lock
	incl	smp_tlb_wait

	popl	%ds
	popl	%eax
	iret

/*
 * Page range TLB shootdown.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(invlrng)
	pushl	%eax
	pushl	%edx
	pushl	%ds
	movl	$KDSEL, %eax		/* Kernel data selector */
	movl	%eax, %ds

#if defined(COUNT_XINVLTLB_HITS) || defined(COUNT_IPIS)
	pushl	%fs
	movl	$KPSEL, %eax		/* Private space selector */
	movl	%eax, %fs
	movl	PCPU(CPUID), %eax
	popl	%fs
#ifdef COUNT_XINVLTLB_HITS
	incl	xhits_rng(,%eax,4)
#endif
#ifdef COUNT_IPIS
	movl	ipi_invlrng_counts(,%eax,4),%eax
	incl	(%eax)
#endif
#endif

	movl	smp_tlb_addr1, %edx
	movl	smp_tlb_addr2, %eax
1:	invlpg	(%edx)			/* invalidate single page */
	addl	$PAGE_SIZE, %edx
	cmpl	%eax, %edx
	jb	1b

	movl	lapic, %eax
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */

	lock
	incl	smp_tlb_wait

	popl	%ds
	popl	%edx
	popl	%eax
	iret

/*
 * Forward hardclock to another CPU.  Pushes a clockframe and calls
 * forwarded_hardclock().
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(ipi_intr_bitmap_handler)	
	
	PUSH_FRAME
	movl	$KDSEL, %eax	/* reload with kernel's data segment */
	movl	%eax, %ds
	movl	%eax, %es
	movl	$KPSEL, %eax
	movl	%eax, %fs

	movl	lapic, %edx
	movl	$0, LA_EOI(%edx)	/* End Of Interrupt to APIC */
	
	FAKE_MCOUNT(TF_EIP(%esp))

	pushl	$0		/* XXX convert trapframe to clockframe */
	call	ipi_bitmap_handler
	addl	$4, %esp	/* XXX convert clockframe to trapframe */
	MEXITCOUNT
	jmp	doreti

/*
 * Executed by a CPU when it receives an Xcpustop IPI from another CPU,
 *
 *  - Signals its receipt.
 *  - Waits for permission to restart.
 *  - Signals its restart.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(cpustop)
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%eax
	pushl	%ecx
	pushl	%edx
	pushl	%ds			/* save current data segment */
	pushl	%es
	pushl	%fs

	movl	$KDSEL, %eax
	movl	%eax, %ds		/* use KERNEL data segment */
	movl	%eax, %es
	movl	$KPSEL, %eax
	movl	%eax, %fs

	movl	lapic, %eax
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */

	movl	PCPU(CPUID), %eax
	imull	$PCB_SIZE, %eax
	leal	CNAME(stoppcbs)(%eax), %eax
	pushl	%eax
	call	CNAME(savectx)		/* Save process context */
	addl	$4, %esp
		
	movl	PCPU(CPUID), %eax

	lock
	btsl	%eax, CNAME(stopped_cpus) /* stopped_cpus |= (1<<id) */
1:
	btl	%eax, CNAME(started_cpus) /* while (!(started_cpus & (1<<id))) */
	jnc	1b

	lock
	btrl	%eax, CNAME(started_cpus) /* started_cpus &= ~(1<<id) */
	lock
	btrl	%eax, CNAME(stopped_cpus) /* stopped_cpus &= ~(1<<id) */

	test	%eax, %eax
	jnz	2f

	movl	CNAME(cpustop_restartfunc), %eax
	test	%eax, %eax
	jz	2f
	movl	$0, CNAME(cpustop_restartfunc)	/* One-shot */

	call	*%eax
2:
	popl	%fs
	popl	%es
	popl	%ds			/* restore previous data segment */
	popl	%edx
	popl	%ecx
	popl	%eax
	movl	%ebp, %esp
	popl	%ebp
	iret

/*
 * Executed by a CPU when it receives a RENDEZVOUS IPI from another CPU.
 *
 * - Calls the generic rendezvous action function.
 */
	.text
	SUPERALIGN_TEXT
IDTVEC(rendezvous)
	PUSH_FRAME
	movl	$KDSEL, %eax
	movl	%eax, %ds		/* use KERNEL data segment */
	movl	%eax, %es
	movl	$KPSEL, %eax
	movl	%eax, %fs

#ifdef COUNT_IPIS
	movl	PCPU(CPUID), %eax
	movl	ipi_rendezvous_counts(,%eax,4), %eax
	incl	(%eax)
#endif
	call	smp_rendezvous_action

	movl	lapic, %eax
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */
	POP_FRAME
	iret
	
/*
 * Clean up when we lose out on the lazy context switch optimization.
 * ie: when we are about to release a PTD but a cpu is still borrowing it.
 */
	SUPERALIGN_TEXT
IDTVEC(lazypmap)
	PUSH_FRAME
	movl	$KDSEL, %eax
	movl	%eax, %ds		/* use KERNEL data segment */
	movl	%eax, %es
	movl	$KPSEL, %eax
	movl	%eax, %fs

#ifdef COUNT_IPIS
	movl	PCPU(CPUID), %eax
	movl	ipi_lazypmap_counts(,%eax,4), %eax
	incl	(%eax)
#endif
	call	pmap_lazyfix_action

	movl	lapic, %eax	
	movl	$0, LA_EOI(%eax)	/* End Of Interrupt to APIC */
	POP_FRAME
	iret
#endif /* SMP */
