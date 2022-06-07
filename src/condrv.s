
	.title	condrv(em).sys based on Console driver Type-D for X68000 version 1.09c


VERSION:	.reg	'1.09c+15'
VERSION_ID:	.equ	'e15 '
DATE:		.reg	'2022-06-08'
AUTHOR:		.reg	'TcbnErik'


# symbols
# __XCONC	XCONC デバイスを使用する
# __EMACS	EMACS 系のキー操作にする
# __EM_FONT_TAB	タブのフォントを MicroEMACS と同じものにする
# __EM_FONT_CR	改行のフォント〃
# __EM_FONT	全てのフォント(現在はタブ、改行)を MicroEMACS と同じものにする
# __UPPER	16 進数の a～f を大文字にする
# __BUF_POS	buffer-position(C-x =)を有効にする
# __TAG_JMP	tag-jump(V)を有効にする

	.ifdef	__EM_FONT
		.ifndef	__EM_FONT_TAB
			__EM_FONT_TAB:	.equ	1
		.endif
		.ifndef	__EM_FONT_CR
			__EM_FONT_CR:	.equ	1
		.endif
	.endif

	.ifdef	__BUF_POS
		.ifndef	__EMACS
			.fail	1
		.endif
	.endif

KEYBIND_TYPE:	.reg	''
		.ifdef	__EMACS
KEYBIND_TYPE:	.reg	'[em]'
		.endif


* Include File -------------------------------- *

		.include	macro.mac
		.include	console.mac
		.include	dosdef.mac
		.include	doscall.mac
		.include	keycode.mac
		.include	iocscall.mac
		.include	gm_internal.mac


* Fixed Number -------------------------------- *

WIDTH:		.equ	96
GETSMAX:	.equ	69			文字列入力の最大バイト数(奇数)
		.fail	(GETSMAX.and.1).eq.0
RL_PASTEBUF:	.equ	general_work+GETSMAX+3	C-^,\ 用のペーストバッファ
KBbuf_Default:	.equ	1024
BLINKCYCLE:	.equ	50
TEXTSAVESIZE:	.equ	128*16*2		桁*ライン*面
IOBUFSIZE:	.equ	TEXTSAVESIZE

;ctype_table
IS_MB_bit:	.equ	7			;2バイト文字の上位バイト
IS_HEX_bit:	.equ	6			;16進数 0-9A-Fa-f
IS_DEC_bit:	.equ	5			;10進数 0-9

BRA_IF_SB:	.macro	ea,label
		tst.b	ea			;btst #IS_MB_bit,ea
		bpl	label
		.endm

BRA_IF_MB:	.macro	ea,label
		tst.b	ea			;btst #IS_MB_bit,ea
		bmi	label
		.endm

CTRL:		.equ	-$40


* Instruction Code ---------------------------- *

RTS:		.equ	$4e75
MOVEM:		.equ	$48e7


* I/O Address --------------------------------- *

TIMERA_VEC:	.equ	$134
CIRQ_VEC:	.equ	$138

TEXT_VRAM:	.equ	$e00000

CRTC_R21:	.equ	$e8002a
CRTC_R22:	.equ	$e8002c
CRTC_MODE:	.equ	$e80480
TEXTPAL:	.equ	$e82200

MFP_GPIP:	.equ	$e88001
MFP_DDR:	.equ	$e88005


* IOCS Work ----------------------------------- *

KEYSTAT:	.equ	$800
LEDSTAT:	.equ	$810
SFTSTAT:	.equ	$811
KBUFNUM:	.equ	$812
CSRSWITCH:	.equ	$992
TXADR:		.equ	$944
TXSTOFST:	.equ	$948
CSRXMAX:	.equ	$970
CSRX:		.equ	$974
FIRSTBYTE:	.equ	$990
TXCOLOR:	.equ	$994
TXUSEMD:	.equ	$9dd
SKEYMOD:	.equ	$bc1
MPUTYPE:	.equ	$cbc

FON_SML8:	.equ	$f3a000


* Macro --------------------------------------- *

INIT_BUFFER_IF_BROKEN: .macro an
		movea.l	(backscroll_buf_adr,pc),an
		cmpi.l	#'hmk*',(an)+
		beq	@skip
		bsr	initialize_backscroll_buffer
@skip:
		.endm

TopChk:		.macro	areg			;前に戻した場合
		.local	skip
		cmpa.l	(buffer_top,a6),areg
		bcc	skip
		adda.l	(buffer_size,pc),areg
skip:
		.endm

EndChk:		.macro	areg			;1byte進めた場合
		.local	skip
		cmpa.l	(buffer_end,a6),areg
		bcs	skip
		movea.l	(buffer_top,a6),areg	;ちょっとだけ速い
skip:
		.endm
EndChk2:	.macro	areg			;複数byte進めた場合
		.local	skip
		cmpa.l	(buffer_end,a6),areg
		bcs	skip
		suba.l	(buffer_size,pc),areg
skip:
		.endm

GMcall:		.macro	callno
		moveq	#.low.callno,d1
		bsr	gm_tgusemd
		.endm

KEYbtst:	.macro	keyname
		btst	#keyname.and.%111,(KEYSTAT+keyname.shr.3)
		.endm
LEDbtst:	.macro	keybit
		btst	#keybit,(LEDSTAT)
		.endm
SFTbtst:	.macro	keybit
		btst	#keybit,(SFTSTAT)
		.endm


* Offset Table -------------------------------- *

bufstruct_size:	.equ	32
		.offset	-4
buffer_id:	.dc.l	1			'hmk*'
buffer_top:	.ds.l	1			バッファ先頭アドレス
buffer_old:	.ds.l	1			リングバッファの一番古いデータのアドレス
buffer_now:	.ds.l	1			現在の行の先頭
buffer_write:	.ds.l	1			書き込みポインタ
buffer_end:	.ds.l	1			バッファ末尾ポインタ
		.ds.l	2			未使用(0)
		.fail	$.ne.(bufstruct_size-4)

		.offset	0			デバイスドライバ入出力のリクエストヘッダ
		.ds.b	1
		.ds.b	1
DEVIO_COMMAND:	.ds.b	1
DEVIO_ERR_LOW:	.ds.b	1
DEVIO_ERR_HIGH:	.ds.b	1
		.ds.b	8
DEVIO_DATABUF:	.ds.b	1
DEVIO_ENDADR:
DEVIO_ADDRESS:	.ds.l	1
DEVIO_ARGUMENT:
DEVIO_LENGTH:	.ds.l	1
		.ds.l	1
REQHEAD_SIZE:
		.fail	REQHEAD_SIZE.ne.26


* Text Section -------------------------------- *

		.cpu	68000

		.text
		.even


* Device Driver Interface --------------------- *

usereg:		.reg	d0-d1/a4-a5

top_:
		.ifdef	__XCONC
			.dc.l	xconc_header
		.else
			.dc.l	-1
		.endif
		.dc	$8020
		.dc.l	xcon_request
		.dc.l	xcon_interrupt
			*01234567
		.dc.l	'XCON    '

		.ifdef	__XCONC
xconc_header:	.dc.l	-1
		.dc	$8000
		.dc.l	xconc_request
		.dc.l	xconc_interrupt
			*01234567
		.dc.l	'XCONC   '

xconc_request:
		move.l	a5,(xconc_req_adr)
		rts
xconc_interrupt:
		PUSH	usereg
		movea.l	(xconc_req_adr,pc),a5
		bra	@f
		.endif

xcon_request:
		move.l	a5,(xcon_req_adr)
		rts
xcon_interrupt:
		PUSH	usereg
		movea.l	(xcon_req_adr,pc),a5
@@:
		moveq	#0,d1
		move.b	(DEVIO_COMMAND,a5),d1
		add	d1,d1
		moveq	#0,d0
		move	(@f,pc,d1.w),d1
		jsr	(@f,pc,d1.w)

		addq.l	#DEVIO_ERR_LOW,a5
		move.b	d0,(a5)+		* DEVIO_ERR_LOW
		move	d0,-(sp)
		move.b	(sp)+,(a5)		* DEVIO_ERR_HIGH

		POP	usereg
		rts

@@:		.dc	xcon_init-@b		 0：初期化
		.dc	xcon_commanderr-@b	 1：エラー
		.dc	xcon_commanderr-@b	 2：未使用
		.dc	xcon_commanderr-@b	 3：IOCTRL による入力
		.dc	xcon_datinp-@b		 4：入力
		.dc	xcon_datsns-@b		 5：先読み入力
		.dc	xcon_inpchk-@b		 6：入力ステータスチェック
		.dc	xcon_commanderr-@b	 7：入力バッファをクリア
		.dc	xcon_output-@b		 8：出力
		.dc	xcon_output-@b		 9：出力(Verify)
		.dc	xcon_ok-@b		10：出力ステータスチェック
		.dc	xcon_commanderr-@b	11：未使用
		.dc	xcon_commanderr-@b	12：IOCTRL による出力

xcon_datsns:
		move.b	d0,(DEVIO_DATABUF,a5)	データが入ってきてない
		rts

xcon_inpchk:
		moveq	#1,d0			常に入力不可
		rts

xcon_datinp:
		move.l	(DEVIO_LENGTH,a5),d0
		beq	xcon_ok
		movea.l	(DEVIO_ADDRESS,a5),a4
@@:
		clr.b	(a4)+
		subq.l	#1,d0
		bne	@b
xcon_ok:
*		moveq	#0,d0
		rts
xcon_commanderr:
		move	#$5003,d0		;コマンドコードが不正
		rts

d0~in_escsq:	.reg	d0
d1~char_code:	.reg	d1
d7~remain:	.reg	d7
a0~input:	.reg	a0
a1~state:	.reg	a1
a2~ctype:	.reg	a2
a3~put_char:	.reg	a3
a4~st_ptr:	.reg	a4

* XCON への出力
xcon_output:
usereg:		.reg	d1~char_code/d2/d7~remain/a0~input/a1~state/a2~ctype/a3~put_char/a4~st_ptr
		PUSH	usereg
		move.l	(DEVIO_LENGTH,a5),d7~remain
		beq	xcon_output_end
		subq.l	#1,d7~remain

		movea.l	(DEVIO_ADDRESS,a5),a0~input
		lea	(ctype_table,pc),a2~ctype
		lea	(condrv_put_char_force,pc),a3~put_char
		lea	(xcon_output_st,pc),a4~st_ptr

		move.l	(a4~st_ptr),d0
		movea.l	d0,a1~state
		bne	@f
		lea	(xcon_output_plain,pc),a1~state
@@:
		move	(xcon_output_hb-xcon_output_st,a4~st_ptr),d1~char_code
		move.b	d1~char_code,d0~in_escsq
xcon_output_loop:
		move.b	(a0~input)+,d1~char_code
*		beq	xcon_output_next	;$00の扱いはput_charに任せる
		jmp	(a1~state)		;状態ごとの処理に分岐

;エスケープシーケンス開始
xcon_output_esc0:
		move.b	d1~char_code,d0~in_escsq	;シーケンス中はput_charをd0.b=$1bで呼び出す
		lea	(xcon_output_esc,pc),a1~state
		bra	xcon_output_putchar
;ESCの次
xcon_output_esc:
		lea	(xcon_output_escbr,pc),a1~state
		cmpi.b	#'[',d1~char_code
		beq	xcon_output_putchar

		subq.l	#xcon_output_escbr-xcon_output_esc2,a1~state
		cmpi.b	#'=',d1~char_code
		beq	xcon_output_putchar

		bra	xcon_output_esc1		;ESC [*DEM0-3]、未対応シーケンス
xcon_output_esc2:
		lea	(xcon_output_esc1,pc),a1~state	;ESC = ... 次の2バイトで終了
		bra	xcon_output_putchar
xcon_output_escbr:
		moveq	#$20,d2				;ESC [ ... @A-Z`a-zで終了
		or.b	d1~char_code,d2
		cmpi.b	#'`',d2
		bcs	xcon_output_putchar
		cmpi.b	#'z',d2
		bhi	xcon_output_putchar
xcon_output_esc1:
		jsr	(a3~put_char)
		moveq	#0,d0~in_escsq			;この文字でエスケープシーケンス終了
		lea	(xcon_output_plain,pc),a1~state
		bra	xcon_output_next

;2バイト文字の上位バイト
xcon_output_mb1:
		move.b	d1~char_code,-(sp)		;lsl #8
		move	(sp)+,d1~char_code
		lea	(xcon_output_mb2,pc),a1~state
		bra	xcon_output_next
;2バイト文字の下位バイト
xcon_output_mb2:
		jsr	(a3~put_char)
		moveq	#0,d1~char_code
		lea	(xcon_output_plain,pc),a1~state
		bra	xcon_output_next

xcon_output_plain:
		BRA_IF_MB (a2~ctype,d1~char_code.w),xcon_output_mb1	;2バイト文字の上位バイト
		cmpi.b	#ESC,d1~char_code
		beq	xcon_output_esc0
xcon_output_putchar:
		jsr	(a3~put_char)
xcon_output_next:
		dbra	d7~remain,xcon_output_loop
		clr	d7~remain
		subq.l	#1,d7~remain
		bcc	xcon_output_loop

		move.l	a1~state,(a4~st_ptr)	;現在の状態を保存
		move.b	d0~in_escsq,d1~char_code
		move	d1~char_code,(xcon_output_hb-xcon_output_st,a4~st_ptr)
xcon_output_end:
		POP	usereg
		moveq	#0,d0
		rts

* End of Device Driver Interface -------------- *

dummy_rte:
		rte

* New IOCS Call ------------------------------- *

iocs_txrascpy:
usereg		.reg	d1-d2/d4/a3
		PUSH	usereg
		lea	(CRTC_R21),a3
		move	(a3),d4
		move	#$010f,d0
		and.b	d3,d0
		move	d0,(a3)
		move	#$0101,d0
		tst	d3
		bpl	@f
		neg	d0			$feff
@@:
		exg	d0,d2
		bsr	txrascpy_sub
		move	d4,(a3)
		POP	usereg
@@:		rts

WAIT_HSYNC	.macro
		.local	skip1,skip2
skip1		tst.b	(a0)
		bmi	skip1
skip2		tst.b	(a0)
		bpl	skip2
		.endm

* in	a3.l	CRTC_R21($e8002a)

txrascpy_sub:
		subq	#1,d0			ラスタコピー
		bmi	@b
usereg		.reg	d4-d6/a0-a2
		PUSH	usereg

		lea	(MFP_GPIP-CRTC_R21,a3),a0
		lea	(CRTC_R22-CRTC_R21,a3),a1
		lea	(CRTC_MODE-CRTC_R21,a3),a2

		moveq	#8,d4
		clr.b	(MFP_DDR-CRTC_R21,a3)
		bset	#0,(a3)			テキスト同時アクセス ON
		move	sr,d5
		move	d5,d6
		ori	#$700,d6
txrascpy_loop:
		move	d6,sr			割り込み禁止
		WAIT_HSYNC

		move	d1,(a1)			転送ラスタ
		move	d4,(a2)			ラスタコピー開始
		move	d5,sr			割り込み許可
		add	d2,d1			次のラスタ
		dbra	d0,txrascpy_loop

		WAIT_HSYNC
		clr	(a2)			ラスタコピー停止
		bclr	#0,(a3)			テキスト同時アクセス OFF
		POP	usereg
		rts


iocs_b_print:
		move.l	d1,-(sp)
		moveq	#0,d1
		move.b	(a1)+,d1
		beq	@f			終わり
1:		bsr	iocs_b_putc
		move.b	(a1)+,d1		次の一文字
		bne	1b
@@:
		move.l	(sp)+,d1
		rts


iocs_b_putc:
		move.b	(FIRSTBYTE),d0
		movea.l	(b_putc_orig,pc),a0
		beq	b_putc_fb0
		bgt	b_putc_go		;ESCシーケンス中 d0.b==$1b

		move.l	d1,-(sp)		;2バイト文字の下位バイト
		move	(FIRSTBYTE),d1
		move.b	(3,sp),d1
		bsr	condrv_put_char
		move.l	(sp)+,d1
b_putc_jmporig:
		jmp	(a0)
b_putc_fb0:
		cmpi	#$0100,d1
		bcc	b_putc_go
		move.b	d1,d0
		bpl	b_putc_go		;ESCの場合、d0.b==$1bでcondrv_put_charを呼ぶ
		lsr.b	#5,d0
		btst	d0,#%1001_0000
		bne	b_putc_jmporig		;2バイト文字の上位バイト
b_putc_go:
		pea	(a0)
		bra	condrv_put_char


* End of New IOCS Call ----------------------- *


* バッファ書き込みルーチン ------------------- *

usereg:		.reg	d0-d4/d7/a0-a6

d0~column:	.reg	d0
d1~char:	.reg	d1
d2~byte:	.reg	d2
d3~temp:	.reg	d3
d4~temp2:	.reg	d4
*d5~unused:	.reg	d5
*d6~unused2:	.reg	d6
d7~line0:	.reg	d7

~a0:		.equ	ctype_table
a0~ctype:	.reg	a0
a1~top:		.reg	a1
a2~old:		.reg	a2
a3~now:		.reg	a3
a4~write:	.reg	a4
a5~end:		.reg	a5
a6~buf:		.reg	a6


* 常に書き込み可能な呼び出しアドレス.
condrv_put_char_force:
		PUSH	usereg
		bra	putbuf_force

condrv_put_char:
		PUSH	usereg
*		rts				;バッファ取り込み停止中

		move	(stop_level,pc),d3~temp	;新バッファ停止処理
		bne	putbuf_cancel
putbuf_force:
		cmpi.b	#ESC,d0
		bne	@f
		move.b	(option_ne_flag,pc),d3~temp
		bne	putbuf_cancel		;ESCシーケンス中
@@:
		INIT_BUFFER_IF_BROKEN a6~buf

		lea	(~a0,pc),a0~ctype
		movem.l	(buffer_top,a6~buf),a1~top/a2~old/a3~now/a4~write/a5~end
		move.b	(putbuf_column-~a0,a0~ctype),d0~column	;現在行の残り桁数
		move.b	(a3~now),d2~byte	;現在行のバイト数
		move.l	(line_buf,pc),d7~line0

		moveq	#0,d3~temp
		move	d1~char,-(sp)
		move.b	(sp)+,d3~temp		;上位byte
		beq	putbuf_1byte
		BRA_IF_SB (a0~ctype,d3~temp.w),putbuf_cancel	;上位バイトが不正な値
		cmpi.b	#$f0,d3~temp
		bcc	putbuf_2byte_hankaku
		cmpi.b	#$80,d3~temp
		bne	putbuf_2byte_zenkaku

putbuf_2byte_hankaku:
		subq.b	#1,d0~column
		bcc	putbuf_2byte

		moveq	#WIDTH-1,d0~column
		bra	@f

putbuf_2byte_zenkaku:
		subq.b	#2,d0~column
		bcc	putbuf_2byte

		moveq	#WIDTH-2,d0~column
@@:		bsr	make_newline_n
putbuf_2byte:
		move.b	d3~temp,(a4~write)+	;上位byte
		bsr	PointerForward

		move.b	d1~char,(a4~write)+	;下位byte
		bne	@f
		move.b	#$20,(-1,a4~write)	;下位バイトが$00なら$20に差し替える
@@:
		bsr	PointerForward

		addq.b	#2,d2~byte
		bra	putbuf_end

putbuf_1byte:
		BRA_IF_MB (a0~ctype,d1~char.w),putbuf_cancel	;2バイト文字の上位バイトだけは不可
		cmpi	#$20,d1~char
		bcs	putbuf_ctrl0~1f		;$00～$1f
		cmpi	#DEL,d1~char
		bne	putbuf_hankaku		;$20-$7e
;putbuf_del:
		move.b	(option_nc_flag,pc),d3~temp
		bne	putbuf_cancel
putbuf_bs:
putbuf_esc:
putbuf_ctrl:
putbuf_hankaku:
		subq.b	#1,d0~column
		bcc	@f

		moveq	#WIDTH-1,d0~column
		bsr	make_newline_n
@@:
		move.b	d1~char,(a4~write)+
		bsr	PointerForward

		addq.b	#1,d2~byte
putbuf_end:
		move.b	d0~column,(putbuf_column-~a0,a0~ctype)	;バッファ書込桁数
		bne	@f
		move.b	#WIDTH,(putbuf_column-~a0,a0~ctype)
		bsr	make_newline_n
@@:
		move.b	d2~byte,(a3~now)	;バッファ書込バイト数
		clr.b	(a4~write)

		movem.l	a2~old/a3~now/a4~write,(buffer_old,a6~buf)
putbuf_nul:
putbuf_esc_ne:
putbuf_ctrl_nc:
putbuf_cancel:
		POP	usereg
		move	d1~char,(bufwrite_last)
		rts

;改行処理

make_newline:
		moveq	#WIDTH,d0~column
make_newline_n:
		move.b	d2~byte,(a3~now)
		move.b	d2~byte,(a4~write)+
		bsr	PointerForward

		moveq	#0,d2~byte

		movea.l	a4~write,a3~now
		clr.b	(a4~write)+
		bra	PointerForward

PointerForward:
		cmpa.l	a5~end,a4~write
		bne	@f
		movea.l	a1~top,a4~write
@@:
		cmpa.l	a4~write,a2~old
		bne	PointerForward_end

		addq.l	#1,a2~old
		cmpa.l	a5~end,a2~old
		bne	@f
		movea.l	a1~top,a2~old
@@:
		cmpa.l	d7~line0,a2~old
		bne	@f
		st	(line_buf-~a0,a0~ctype)
@@:
		moveq	#0,d4~temp2
		cmpa.l	(mark_line_adr-~a0,a0~ctype),a2~old
		bne	@f
		move.l	d4~temp2,(mark_char_adr-~a0,a0~ctype)
		move.l	d4~temp2,(mark_line_adr-~a0,a0~ctype)
@@:
		move.b	(a2~old)+,d4~temp2
		adda	d4~temp2,a2~old
		cmpa.l	a5~end,a2~old
		bcs	@f
		suba.l	(buffer_size,pc),a2~old
@@:
		clr.b	(a2~old)
PointerForward_end:
		rts

;制御記号の処理

putbuf_lf:
		moveq	#CR,d1~char
putbuf_cr:
		cmp	(bufwrite_last,pc),d1~char
		beq	putbuf_cancel		;前回も CR だったら無視

		tst.b	d0~column
		bne	@f

		bsr	make_newline_n		;d0初期化は不要
@@:
		move.b	d1~char,(a4~write)+
		bsr	PointerForward

		addq.b	#1,d2~byte

		bsr	make_newline
		bra	putbuf_end

putbuf_tab:
		tst.b	d0~column
		bne	@f

		bsr	make_newline
@@:
		move.b	d1~char,(a4~write)+
		bsr	PointerForward

		subq.b	#1,d0~column
putbuf_tab_end:
		andi.b	#.not.7,d0~column
		addq.b	#1,d2~byte
		bra	putbuf_end

putbuf_tab_nt:
		tst.b	d0~column		;TAB 処理(-nt)
		bne	@f

		bsr	make_newline
@@:
		subq.b	#1,d0~column
		moveq	#%111,d3~temp
		and.b	d0~column,d3~temp
		add.b	d3~temp,d2~byte

		moveq	#SPACE,d1~char
putbuf_tab_loop:
		move.b	d1~char,(a4~write)+	;TABをSPACEに変換
		bsr	PointerForward
		dbra	d3~temp,putbuf_tab_loop
		bra	putbuf_tab_end

putbuf_bs_nb:
		subq.b	#1,d2~byte		;BS 処理(-nb)
		bcs	putbuf_cancel		;カーソルが行の左端にある

		addq.b	#1,d0~column		;1 バイト削除
		subq.l	#1,a4~write
		TopChk	a4~write

* 1 バイト半角文字を BS 一個で削除する

* 直前の 1 バイトが $80、$f0-$ff なら、今削除した
* 1 バイトと合わせて 2 バイト半角文字の可能性がある.

		move.b	d2~byte,-(sp)
		subq.b	#1,d2~byte
		bcs	putbuf_bs_end		;カーソルが行の左端にある

		move.l	a4~write,-(sp)
		subq.l	#1,a4~write
		TopChk	a4~write
		cmpi.b	#$80,(a4~write)
		beq	putbuf_bs_check		;2 バイト半角
		cmpi.b	#$f0,(a4~write)
		bcc	putbuf_bs_check		;〃
		movea.l	(sp)+,a4~write
putbuf_bs_end:
		move.b	(sp)+,d2~byte		;更なる削除は不要だった
		bra	putbuf_end
putbuf_bs_check:

* ..	削除した 1 バイト
* XX	その直前($80、$f0-$ff)
* aa～	更に前方
* aa bb cc dd XX ..

* データ列がどのように文字を構成するかを考える.
* aa bb [cc dd] [XX ..]
* というように [cc dd]、[XX ..] が組として 2 バイト文字を
* 構成しているなら、更にもう 1 バイト、XX を削除する.
* aa [bb cc] [dd XX] ..
* というように [bb cc] [dd XX] が組になっているなら削除は
* しない.

* 1)[dd XX] が成立するかを調べる.
*   成立しなければ [XX ..] が確定する.
* 2)[dd XX] が成立すれば [XX ..] は成り立たないが、現在の
*   情報では手前の [cc dd] が成立する可能性を否定できない.
*   もしそれが成立するなら、[cc dd] [XX ..] が確定し、本当
*   はどちらなのか分からなくなる.
* 3)よって、[cc dd] が成立するかを調べる.
*   成立しなければ [dd XX] が確定する.
* 4)[cc dd] が確定すれば [XX ..] も確定するが、[bb cc] に
*   ついても同様の疑問が生じる.
* 5)[bb cc]、[aa bb] など成立する限り前方のデータを調べる.
* 6)最後に成立した位置から 2 バイトずつ組を作っていけば
*   [dd XX] なのか [XX ..] なのかが分かる. これは、XX より
*   手前で成立したバイト数が奇数か偶数かで判断できる.

putbuf_bs_loop:
		subq.b	#1,d2~byte
		bcs	putbuf_bs_loop_end	;もう文字が残っていない
		subq.l	#1,a4~write
		TopChk	a4~write
		move.b	(a4~write),d3~temp	;$80-$9f -> 4
		lsr.b	#5,d3~temp		;$e0-$ff -> 7
		btst	d3~temp,#(1<<4)+(1<<7)
		bne	putbuf_bs_loop		;更に前方を調べる
putbuf_bs_loop_end:
		movea.l	(sp)+,a4~write
		.if	0
* ループ開始時の d2~byte は (sp).b の値より 1 小さい.
* ループ条件不成立時にも d2~byte から 1 を引いている.
		addq.b	#2,d2~byte		;上記二点の分を補正
		sub.b	(sp),d2~byte
		neg.b	d2~byte			;成立したバイト数(XX は含まない)
		.else
		sub.b	(sp),d2~byte		;高速化
		.endif
		lsr.b	#1,d2~byte
		bcs	putbuf_bs_end		;奇数なら [dd XX] なので削除は不要

* 偶数(0 の場合も含む)なら [cc dd] [XX ..] なので、
* もう 1 バイト削除する.

		move.b	(sp)+,d2~byte
		subq.b	#1,d2~byte
		addq.b	#1,d0~column		;1 バイト削除
		subq.l	#1,a4~write
		TopChk	a4~write

		bra	putbuf_end

***
putbuf_ctrl0~1f:
		move	d1~char,d3~temp
		add	d1~char,d3~temp
		move	(putbuf_ctrl_table,pc,d3~temp.w),d3~temp
		jmp	(putbuf_ctrl_table,pc,d3~temp.w)


;制御記号の処理分岐表

DCR:		.macro	num,addr
		.rept	num
		.dc	addr-putbuf_ctrl_table
		.endm
		.endm

putbuf_ctrl_table:
		DCR	 1,putbuf_nul		;$00
		DCR	 7,putbuf_ctrl		;$01～$07
		DCR	 1,putbuf_bs		;$08
		DCR	 1,putbuf_tab		;$09
		DCR	 1,putbuf_lf		;$0a
		DCR	 2,putbuf_ctrl		;$0b～$0c
		DCR	 1,putbuf_cr		;$0d
		DCR	13,putbuf_ctrl		;$0e～$1a
		DCR	 1,putbuf_esc		;$1b
		DCR	 4,putbuf_ctrl		;$1c～$1f

;-ncでputbuf_ctrl_ncに書き換えるコード=1
PUT_CTRL_LIST:	.equ	%1111_0_1111111111111_0_11_000_1111111_0
			;fedc_b_a9876543210fe_d_cb_a98_7654321_0


* New DOS Call -------------------------------- *

dos_fnckey:
		pea	(display_system_status,pc)
		move.l	(fnckey_orig,pc),-(sp)
		rts

dos_hendsp:
		cmpi	#3,(a6)
		beq	dos_hendsp_close	モード表示ウィンドウをクローズ
		tst	(a6)
		bne	call_original_dos_hendsp
		bset	#FEPOPEN_bit,(bitflag)	モード表示ウィンドウをオープン
call_original_dos_hendsp:
		move.l	(hendsp_orig,pc),-(sp)
		rts

dos_hendsp_close:
		bsr	call_original_dos_hendsp
		bclr	#FEPOPEN_bit,(bitflag)	閉じた
		bra	display_system_status

dos_conctrl:
		cmpi	#$e,(a6)
		bne	call_original_dos_conctrl

		move	(2,a6),d0
		bmi	dos_conctrl_getfncmode
		bsr	set_funcdisp_flag
		bsr	call_original_dos_conctrl
display_system_status:
		move.b	(bitflag,pc),-(sp)
*		andi.b	#IS_FEPOPEN.or.IS_NO_FUNC.or.IS_GETSS,(sp)+
		andi.b	#IS_FEPOPEN.or.IS_NO_FUNC,(sp)+
		bne	display_sys_stat_end
		btst	#OPT_F_bit,(option_flag,pc)
		bne	display_sys_stat_end

usereg		.reg	d0-d4/a1
		PUSH	usereg
		lea	(sys_stat_prtbuf,pc),a1
		move.b	(stop_level_char,pc),d0
		bne	disp_sys_stat_set	;'1'～'9'

		cmpi	#RTS,(condrv_put_char-sys_stat_prtbuf,a1)
		sne	d0
		addi.b	#'!',d0
		.fail	('!'-1).ne.SPACE
disp_sys_stat_set:
		move.b	d0,(a1)

		move.b	(option_f_col,pc),d1	表示属性
		moveq	#0,d2			左端
		moveq	#31,d3			最下行
		cmpi.b	#18,($93c)		CRTMOD
		bne	@f
		moveq	#848/16-1,d3
@@:		moveq	#2-1,d4			2文字
		IOCS	_B_PUTMES
		POP	usereg
display_sys_stat_end:
		rts

dos_conctrl_getfncmode:
		bsr	call_original_dos_conctrl
		bsr	set_funcdisp_flag
		bra	display_system_status

set_funcdisp_flag
usereg		.reg	d0-d1/a0
		PUSH	usereg
		lea	(bitflag,pc),a0
		moveq	#NO_FUNC_bit,d1

		bset	d1,(a0)
		cmpi	#2,d0
		bcc	@f		2以下なら表示しても良い
		bchg	d1,(a0)
@@:
		POP	usereg
		rts

call_original_dos_conctrl:
		move.l	(conctrl_orig,pc),-(sp)
		rts

* Condrv Official Work ------------------------ *

		.even
stop_level:	.dc	0
option_flag:
		.dc.b	0
OPT_J_bit:	.equ	7 : -j(コード入力時に16進数文字のみペーストする)
OPT_S_bit:	.equ	3 : -s(EMACS mode でもスクロールを ED 式にする)
OPT_G_bit:	.equ	2 : -g(stop_level > 0 の時'!'の代わりにその値を表示する)
OPT_BG_bit:	.equ	1 : BG対応(sleepする - これは-zの筈だった)
OPT_F_bit:	.equ	0 : -f(!を表示しない)
		.even
		.dc	0,0			ペーストのウェイトカウンタ/初期値(未使用)
		.dc.l	condrv_system_call
nul_string:
		.dc.b	0			;空文字列(常に NUL)
keyctrl_flag:
		.dc.b	0			-1:キー操作抑制
		.dc.l	condrv_put_char
pastebuf_size:
		.dc.l	KBbuf_Default
pastebuf_adr:
		.dc.l	keypaste_buffer
		.dc.l	'hmk*'

* IOCS _KEY_INIT ------------------------------ *

iocs_key_init:
.if 0  ;有効にしないのはなにか理由があったような気がする
		move.l	(key_init_orig,pc),-(sp)
.else
		move.l	(key_init_orig,pc),d0
		move.l	d0,-(sp)
.endif
		bra	initialize_keypaste_buffer

* キーバッファ初期化 -------------------------- *

initialize_keypaste_buffer:
		lea	(nul_string,pc),a0	;NUL はワーク内のアドレスを設定
		move.l	a0,(paste_pointer-nul_string,a0)
		adda.l	(pastebuf_size,pc),a0	;バッファ末尾に番兵を置く
		clr.b	(keypaste_buffer-nul_string-1,a0)
		rts


* バックログバッファ初期化 -------------------- *

check_backscroll_buffer:
		INIT_BUFFER_IF_BROKEN a6
		rts

initialize_backscroll_buffer:
usereg:		.reg	d0/a5-a6
		PUSH	usereg
		moveq	#0,d0
		movea.l	(backscroll_buf_adr,pc),a6
		lea	(bufstruct_size,a6),a5

		move.l	#'hmk*',(a6)+
		move.l	a5,(a6)+		BufTop
		.rept	3
		move.l	a5,(a6)+		先頭行/現在行/書き込みポインタ
		move.b	d0,(a5)+
		.endm
		subq.l	#3,a5
		adda.l	(buffer_size,pc),a5
		move.l	a5,(a6)+		BufEnd
		move.l	d0,(a6)+		未使用
		move.l	d0,(a6)			〃

		lea	(line_buf,pc),a5
		st	(a5)
		move	d0,(bufwrite_last-line_buf,a5)
		move.b	#WIDTH,(putbuf_column-line_buf,a5)

		POP	usereg
		rts


* IOCS _B_KEYINP ------------------------------ *

iocs_b_keyinp:
		bsr	iocs_b_keysns
		tst.l	d0
		beq	iocs_b_keyinp
call_orig_b_keyinp:
		move.l	(b_keyinp_orig,pc),-(sp)
		rts

* IOCS _B_KEYSNS ------------------------------ *

iocs_b_keysns:
		movea.l	(paste_pointer,pc),a0
		moveq	#0,d0
		move.b	(a0)+,d0
		beq	not_paste_mode

		KEYbtst	KEY_ESC
		bne	paste_stop		* ESC が押されていたらペーストを中止する

		tst	(KBUFNUM)
		bne	not_paste_mode		* キーが入力されている

usereg:		.reg	d1-d2/a1-a3
		PUSH	usereg
		move	sr,-(sp)

		lea	(ctype_table,pc),a3
		moveq	#0,d1			一応クリア
		moveq	#0,d2			-1:2バイト文字処理中

		ori	#$700,sr
paste_one_more_char:
		lea	(KBUFNUM),a2
		movea.l	(2,a2),a1
		addq.l	#2,a1
		cmpa	#$89c,a1
		bcs	@f
		lea	($81c),a1
@@:
		bclr	#AFTERCR_bit,(bitflag)
		beq	paste_without_header	普通に出力

		move.b	(option_flag,pc),d1	-j
		bpl	@f			コード入力モードでなければヘッダあり

		LEDbtst	LED_コード
		bne	paste_without_header	コード入力モードでは常にヘッダを出力しない
@@:
		move.b	(paste_header,pc),d1
		beq	paste_without_header

		move	d1,(a1)
		addq	#1,(a2)+
		move.l	a1,(a2)
		bra	paste_char_end

paste_without_header:
		move.l	a0,(paste_pointer)
		move.b	(option_flag,pc),d1	-j
		bpl	@f
		LEDbtst	LED_コード
		beq	@f
		btst.b	#IS_HEX_bit,(a3,d0.w)
		beq	paste_char_end		;16進数文字(0-9A-Fa-f)でなければペーストしない
@@:
		move	d0,(a1)
		addq	#1,(a2)+
		move.l	a1,(a2)

		BRA_IF_SB (a3,d0.w),@f		;1バイト文字
		tst	d2
		bne	paste_char_end

		moveq	#-1,d2
		move.b	(a0)+,d0		２バイト目を処理
		bne	paste_one_more_char
		bra	paste_char_end
@@:
		cmpi.b	#CR,d0
		bne	paste_char_end
		bset	#AFTERCR_bit,(bitflag)
paste_char_end:
		move	(sp)+,sr
		POP	usereg			* ペーストしたらキーチェックは不要
call_orig_b_keysns:
		move.l	(b_keysns_orig,pc),-(sp)
		rts

not_paste_mode:
usereg:		.reg	d1-d7/a0-a6
		PUSH	usereg
* sleep対応 {
		move.b	(sleep_flag,pc),d0
		bne	wakeup_backscroll
* }
		bsr	call_orig_b_keysns

		btst	#BACKSCR_bit,(bitflag,pc)
		bne	iocs_keysns_return

		move	d0,-(sp)
		move.b	(sp)+,d1
		beq	iocs_keysns_return
		move.b	(keyctrl_flag,pc),d2
		bne	iocs_keysns_return

		lea	(SFTSTAT),a0
		btst	#SFT_CTRL,(a0)
		beq	@f

KEYCHK:		.macro	keycode,address
		cmpi.b	#keycode,d1
		beq	address
		.endm

		KEYCHK	KEY_4   ,direct_key_paste
		KEYCHK	KEY_HELP,direct_key_paste
		KEYCHK	KEY_BS  ,direct_key_toggle
		KEYCHK	KEY_CLR ,direct_key_clear

		KEYCHK	KEY_1,direct_key_backscroll_1
		KEYCHK	KEY_2,direct_key_backscroll_2
@@:
		move.b	(option_o_flag,pc),d2
		btst	d2,(a0)
		beq	iocs_keysns_return

		KEYCHK	KEY_↑  ,direct_key_backscroll_2
		KEYCHK	KEY_↓  ,direct_key_backscroll_1
		KEYCHK	KEY_UNDO,direct_key_backscroll_1
@@:
		btst	#SUSPEND_bit,(bitflag,pc)
		beq	iocs_keysns_return

* バックログを開いたまま終了した場合に有効なキー
		KEYCHK	KEY_←    ,direct_key_left
		KEYCHK	KEY_→    ,direct_key_right
		KEYCHK	KEY_R_DOWN,direct_key_rolldown
		KEYCHK	KEY_R_UP  ,direct_key_rollup
iocs_keysns_return:
		POP	usereg
		rts

iocs_keysns_flush:
		bsr	call_orig_b_keyinp
iocs_keysns_return_0:
		moveq	#0,d0
		bra	iocs_keysns_return

* ccrZ=1でテキスト使用中
is_text_used:
		cmpi.b	#2,(TXUSEMD)		;テキスト画面の使用モード
		bne	@f
		btst	#2,(option_m_flag,pc)
@@:		rts

* ペーストを中止する
paste_stop:
		bsr	initialize_keypaste_buffer
@@:
		KEYbtst	KEY_ESC
		bne	@b			;ESCが離されるまで待つ
keybuf_clear:
		moveq	#0,d0
		lea	(KBUFNUM),a0
		move	d0,(a0)+
		move.l	(a0)+,(a0)
		rts				;0を返す

* ^4 , ^HELP : カットした領域をペースト
direct_key_paste:
		bsr	yank_sub
		bsr	wait_release_ctrl_key
		bra	iocs_keysns_flush

* ^BS : バッファ取り込み中断/再開
direct_key_toggle:
		bsr	key_toggle_buffering_mode
		bra	iocs_keysns_flush

* ~ROLL DOWN : ウィンドウ位置を上げる
direct_key_rolldown:
		bsr	is_text_used
		beq	@f

		bsr	key_slide_window_up
@@:
		bra	iocs_keysns_flush

* ~ROLL UP : ウィンドウ位置を下げる
direct_key_rollup:
		bsr	is_text_used
		beq	@f

		bsr	key_slide_window_down
@@:
		bra	iocs_keysns_flush

* ~← : スクロールアップ
direct_key_left:
		bsr	is_text_used
		beq	@f

		bsr	direct_key_rl_sub
		bsr	key_move_window_up
@@:
		bra	iocs_keysns_flush

* ~→ : スクロールダウン
direct_key_right:
		bsr	is_text_used
		beq	@f

		bsr	direct_key_rl_sub
		move	(window_line,pc),d0
		bsr	draw_line_d0
		bsr	key_move_window_down
@@:
		bra	iocs_keysns_flush

direct_key_rl_sub:
		bsr	check_backscroll_buffer
		move	(line_buf,pc),d0
		bmi	key_beginning_of_buffer
		rts

* ^CLR : バッファ消去
direct_key_clear:
		bsr	initialize_backscroll_buffer
		bra	iocs_keysns_flush

* 文字表示ルーチン ---------------------------- *

* 指定行(d0.w)を描画
draw_line_d0:
usereg		.reg	d1/a1-a2		d0 も破壊しないこと
		PUSH	usereg
		lea	(line_buf,pc),a3
		moveq	#0,d1
		move	d0,d1
		lsl	#2,d1
		movea.l	(a3,d1.w),a1
		move	d0,d1
		swap	d1
		lsr.l	#5,d1
		movea.l	(text_address,pc),a2
		adda.l	d1,a2			指定行のアドレス
		bsr	draw_line
		POP	usereg
		rts

draw_line:
usereg		.reg	d0-d5/a0-a2/a4-a5
		PUSH	usereg
		move.l	a1,d0
		bpl	@f
		lea	(nul_string,pc),a1
@@:
		.ifdef	__EMACS
			moveq	#0,d5
		.else
		lea	(line_buf,pc),a5	;マーク境界の算出
		move	(cursorY,pc),d1
		lsl	#2,d1
		movea.l	(a5,d1.w),a4
		adda	(cursorXbyte,pc),a4
		addq.l	#1,a4
		EndChk2	a4
		movea.l	(mark_char_adr,pc),a5
		cmpa.l	a4,a5
		bcc	@f
		exg	a4,a5
@@:
		.endif
		moveq	#0,d3
		move.b	(a1)+,d3
		EndChk	a1
		moveq	#0,d4
		bra	draw_line_

draw_line_loop:
		.ifndef	__EMACS
		move.l	(mark_char_adr,pc),d5
		beq	draw_line_nomark
		moveq	#0,d5
		cmpa.l	(buffer_old,a6),a4
		bcc	@f
		cmpa.l	(buffer_old,a6),a5
		bcs	@f
		cmpa.l	a4,a1
		bcs	draw_line_mark
		cmpa.l	a5,a1
		bcs	draw_line_nomark
		bra	draw_line_mark
@@:
		cmpa.l	a4,a1
		bcs	draw_line_nomark
		cmpa.l	a5,a1
		bcc	draw_line_nomark
draw_line_mark:
		moveq	#-1,d5
draw_line_nomark:
		.endif
		move.b	(a1)+,d1
		EndChk	a1
		tst.b	d1
		bpl	@f			$00-$7f
		cmpi	#$a0,d1
		bcs	draw_line_2byte		$80-$9f
		cmpi	#$e0,d1
		bcs	@f			$a0-$df
draw_line_2byte:
		lsl	#8,d1
		move.b	(a1)+,d1
		EndChk	a1
		subq	#1,d3
		bcs	draw_line_abort
@@:
		bsr	draw_char_d1
draw_line_:
		moveq	#0,d1
		dbra	d3,draw_line_loop
draw_line_abort:
		.ifndef	__EMACS
			moveq	#0,d5
		.endif
		bra	@f
draw_space_loop:
		bsr	draw_space
@@:
		cmpi.b	#WIDTH,d4
		bcs	draw_space_loop
		POP	usereg
		rts

draw_space:
		addq	#1,d4
		move.b	d5,(a2)+
_offset		.set	$80
		.rept	16-1
		move.b	d5,(_offset-1,a2)
_offset		.set	_offset+$80
		.endm
		rts

draw_char_d1:
		cmpi	#$20,d1
		bhi	draw_char_fntadr	普通の文字
		beq	draw_space

		cmpi	#CR,d1
		bne	is_tab

		lea	(cr_font,pc),a0
		tst.b	(option_r_flag-cr_font,a0)
		bne	draw_char_condrv_font	-r 指定時は改行記号を表示
		rts
is_tab:
		cmpi	#TAB,d1
		bne	draw_char_fntadr	その他の制御コード

		lea	(tab_font_1,pc),a0
		tst.b	(option_t_flag-tab_font_1,a0)
		beq	draw_invisible_tab
@@:
		bsr	draw_char_condrv_font	-t 指定時はTAB記号を表示
		lea	(tab_font_2,pc),a0
		moveq	#%111,d1		8の倍数カラムまで描画
		and	d4,d1
		bne	@b
		rts
draw_invisible_tab:
		bsr	draw_space
		moveq	#%111,d1
		and	d4,d1
		bne	draw_invisible_tab
		rts

draw_char_fntadr:
		moveq	#8,d2
		movea.l	(_FNTADR*4+$400),a0
		jsr	(a0)
		movea.l	d0,a0
		tst	d1
		bne	draw_widechar		全角文字
draw_char_condrv_font:
		.ifndef	__EMACS
			tst.b	d5		反転か？
			bne	draw_char_reverse
		.endif

		addq	#1,d4			半角
		move.b	(a0)+,(a2)+
_offset		.set	$80
		.rept	16-1
		move.b	(a0)+,(_offset-1,a2)
_offset		.set	_offset+$80
		.endm
		rts

draw_widechar:
		.ifndef	__EMACS
			tst.b	d5
			bne	draw_widechar_reverse
		.endif

		addq	#2,d4			全角
		move.b	(a0)+,(a2)+
		move.b	(a0)+,(a2)+
_offset		.set	$80
		.rept	16-1
		move.b	(a0)+,(_offset-2,a2)
		move.b	(a0)+,(_offset-1,a2)
_offset		.set	_offset+$80
		.endm
		rts

		.ifndef	__EMACS
draw_char_reverse:
		addq	#1,d4			半角反転
		move.b	(a0)+,d0
		not.b	d0
		move.b	d0,(a2)+
_offset		.set	$80
		.rept	16-1
		move.b	(a0)+,d0
		not.b	d0
		move.b	d0,(_offset-1,a2)
_offset		.set	_offset+$80
		.endm
		rts

draw_widechar_reverse:
		addq	#2,d4			全角反転
		.rept	2
		move.b	(a0)+,d0
		not.b	d0
		move.b	d0,(a2)+
		.endm
_offset		.set	$80
		.rept	16-1
		move.b	(a0)+,d0
		not.b	d0
		move.b	d0,(_offset-2,a2)
		move.b	(a0)+,d0
		not.b	d0
		move.b	d0,(_offset-1,a2)
_offset		.set	_offset+$80
		.endm
		rts
		.endif


		.ifndef	__EMACS
draw_char_c:
usereg		.reg	d0-d7/a0-a5
		PUSH	usereg

		lea	(line_buf,pc),a3
		moveq	#0,d5
		move	d7,d2			cursorY
		lsl	#2,d2
		movea.l	(a3,d2.w),a1
		adda	d6,a1
		addq.l	#1,a1
		EndChk	a1
		moveq	#0,d2
		move	d7,d2
		swap	d2
		lsr.l	#5,d2
		movea.l	(text_address,pc),a2
		adda.l	d2,a2
		swap	d6
		adda	d6,a2
		move	d6,d4

		move	(cursorY,pc),d1
		lsl	#2,d1
		movea.l	(a3,d1.w),a4
		adda	(cursorXbyte,pc),a4
		addq.l	#1,a4
		EndChk2	a4
		movea.l	(mark_char_adr,pc),a5
		cmpa.l	a4,a5
		bcc	@f
		exg	a4,a5
@@:
		move.l	(mark_char_adr,pc),d1
		beq	draw_char_c_nomark
		cmpa.l	(buffer_old,a6),a4
		bcc	@f
		cmpa.l	(buffer_old,a6),a5
		bcs	@f
		cmpa.l	a4,a1
		bcs	draw_char_c_mark
		cmpa.l	a5,a1
		bcs	draw_char_c_nomark
		bra	draw_char_c_mark
@@:
		cmpa.l	a4,a1
		bcs	draw_char_c_nomark
		cmpa.l	a5,a1
		bcc	draw_char_c_nomark
draw_char_c_mark:
		moveq	#-1,d5			反転
draw_char_c_nomark:
		moveq	#0,d1
		move.b	(a1)+,d1
		bpl	@f
		cmpi	#$a0,d1
		bcs	draw_char_c_2byte
		cmpi	#$e0,d1
		bcs	@f
draw_char_c_2byte:
		EndChk	a1			;ここで調べれば半角の時速い
		lsl	#8,d1
		move.b	(a1),d1
@@:
		bsr	draw_char_d1
		POP	usereg
		rts
		.endif


* カーソル描画 -------------------------------- *

blink_cursor:
		IOCS	_ONTIME
		move.l	d0,d2
		lea	(last_time,pc),a0
		move.l	(a0),d1
		cmp.l	d1,d2
		bcc	@f

		addi.l	#99*60*60*24,d2		24時間経過して 0 に戻った時の補正
@@:
		sub.l	d1,d2			経過時間
		moveq	#0,d1
		move.b	(cursor_blink_count,pc),d1
		cmp.l	d1,d2
		bcs	blink_cursor_end	まだ時間がたっていない

		move.l	d0,(a0)			カーソル点滅時刻を更新
		move.b	#BLINKCYCLE,(cursor_blink_count-last_time,a0)
		bra	blink_cursor_sub

clear_cursor:
		move.l	a0,-(sp)
		lea	(cursor_blink_count,pc),a0
		clr.b	(a0)+
		tst.b	(a0)			cursor_blink_state
		movea.l	(sp)+,a0
		beq	blink_cursor_end

blink_cursor_sub:
usereg		.reg	d0/a1-a2
		PUSH	usereg
		lea	(cursor_blink_state,pc),a2
		not.b	(a2)
		movea.l	(text_address,pc),a2
		adda	(cursorX,pc),a2
		moveq	#0,d0
		move	(cursorY,pc),d0
		swap	d0
		lsr.l	#5,d0
		adda.l	d0,a2
@@:
		lea	(CRTC_R21),a1
		move	(a1),d0
		bclr	#0,(a1)
_offset		.set	0
		.rept	16
		not.b	(_offset,a2)
_offset		.set	_offset+$80
		.endm
		move	d0,(a1)
		POP	usereg
blink_cursor_end:
		rts

blink_cursor_direct:
		PUSH	usereg
		movea.l	(mes_end_adr,pc),a2
		bra	@b


* IOCS _B_KEYSNS からのキー入力 --------------- *

* ^2 , ~↑ : バッファの最後からバックログに入る
direct_key_backscroll_2:
		bsr	is_text_used
		beq	iocs_keysns_flush

		bsr	check_backscroll_buffer
		bsr	end_of_buffer_sub

		lea	(cursorY,pc),a0
		move	d2,(a0)
		bpl	@f
		clr	(a0)
@@:		st	(cursorX-cursorY,a0)	;最終行右端に移動
into_backscroll_at_lastpos:
		bsr	check_column
* sleep対応 {
		bsr	tst_and_clr_sleep_flag
		beq	into_backscroll_open_draw

		lea	(last_line_ptr,pc),a2
		movea.l	(a2)+,a0		;last_line_ptr
		movea.l	(a0),a1			;現在のアドレス
		cmpa.l	(a2),a1			;last_line_adr
		bne	into_backscroll_redraw
		tst.l	(a2)+
		bmi	into_backscroll_skip_draw
		cmpm.b	(a2)+,(a1)+		;last_line_byte
		beq	into_backscroll_skip_draw
into_backscroll_redraw:
		bsr	clear_cursor
		bsr	check_column

		move.l	a0,d0
		pea	(line_buf,pc)
		sub.l	(sp)+,d0
		lsr	#2,d0			;d0=last_line
into_backscroll_redraw_loop:
		tst.l	(a0)+
		bmi	into_backscroll_skip_draw
		bsr	draw_line_d0
		addq	#1,d0
		cmp	(window_line,pc),d0
		bls	into_backscroll_redraw_loop
		bra	into_backscroll_skip_draw

tst_and_clr_sleep_flag:
		lea	(sleep_flag,pc),a0
		tst.b	(a0)
		sf	(a0)
		rts

into_backscroll_at_top:
		bsr	tst_and_clr_sleep_flag
		bne	into_backscroll_skip_open
into_backscroll_open_draw:
		bsr	call_orig_b_keyinp	;オープン時のキー入力を消す
		bsr	open_backscroll_window
into_backscroll_skip_open:
		bsr	draw_backscroll
into_backscroll_skip_draw:
		bclr	#SUSPEND_bit,(bitflag)
* }
		bsr	keyinp_loop_start	;メインループ
* sleep対応 {
		move.b	(sleep_flag,pc),d0
		beq	not_sleep_exit

		move	(window_line,pc),d0
		lea	(line_buf,pc),a0
		tst.l	(a0)
		bmi	@f
get_last_line_loop:
		tst.l	(a0)+
		dbmi	d0,get_last_line_loop
		subq.l	#4,a0
		bpl	@f
		subq.l	#4,a0
@@:		lea	(last_line_ptr,pc),a2
		movea.l	(a0),a1
		move.l	a0,(a2)+		;last_line_ptr
		move.l	a1,(a2)+		;last_line_adr
		move.l	a1,d0
		bmi	@f
		move.b	(a1),(a2)+		;last_line_byte
@@:		bra	iocs_keysns_return_0

not_sleep_exit:
* }
		bsr	close_backscroll_window
		bsr	wait_release_ctrl_key
		bra	iocs_keysns_return_0

wait_release_ctrl_key:
		move.b	(option_p_flag,pc),d0
		beq	1f
		move.l	(paste_pointer,pc),a0
		tst.b	(a0)
		beq	1f
@@:
		SFTbtst	SFT_CTRL
		bne	@b
1:
		rts


* ^1 , ~↓ , ~UNDO : 最後のカーソル位置からバックログに入る
direct_key_backscroll_1:
		bsr	is_text_used
		beq	iocs_keysns_flush
wakeup_backscroll:
		bsr	check_backscroll_buffer

		move	(line_buf,pc),d0
		bmi	@f			;押し出されていた時は一番古い位置を表示

		bsr	reset_line_address_buf
		bra	into_backscroll_at_lastpos
@@:
		bsr	clear_cursor
		bsr	beginning_of_buffer_sub
		lea	(cursorX,pc),a0
		clr.l	(a0)+			;cursorX/Xbyte
		clr	(a0)			;cursorY
		bra	into_backscroll_at_top

end_of_buffer_sub:
		moveq	#-1,d2
		move	(window_line,pc),d1
		lea	(line_buf,pc),a3
		move	d1,d0
@@:
		move.l	d2,(a3)+		;行アドレスバッファを埋める
		dbra	d0,@b

		movea.l	(buffer_now,a6),a0
scroll_down_loop:
		movea.l	a3,a1			;a1=最後+1
		lea	(-4,a1),a2		;a2=最後
		move	d1,d0
		subq	#1,d0
@@:
		move.l	-(a2),-(a1)		;下にずらす
		dbra	d0,@b

		move.l	a0,(a2)
		addq	#1,d2
scroll_down_p_sub:
		subq.l	#1,a0
		TopChk	a0
		moveq	#0,d0
		move.b	(a0),d0
		beq	end_of_buffer_end	;これより前の行はない
		suba	d0,a0
		subq.l	#1,a0
		TopChk	a0

		cmp	d1,d2			行数-1>表示行数-1
*		bcs	scroll_down_loop
		blt	scroll_down_loop	d2=$ffffの時も繰り返す
end_of_buffer_end:
		rts

reset_line_address_buf:
		movea.l	(line_buf,pc),a0
reset_line_address_buf_2:
		bsr	fill_line_address_buf
		move.l	a0,d0			;バッファが空の時は全て-1で埋める
		bpl	@f
		rts

beginning_of_buffer_sub:
		bsr	fill_line_address_buf
		movea.l	(buffer_old,a6),a0
		addq.l	#1,a0
set_line_address_loop:
		EndChk	a0
@@:
		moveq	#0,d0
		move.b	(a0),d0
		move.l	a0,(a3)+
		addq.l	#1,a0
		adda	d0,a0
		EndChk2	a0
		tst.b	(a0)+
		dbeq	d1,set_line_address_loop
@@:
		rts

fill_line_address_buf:
		moveq	#-1,d2
		move	(window_line,pc),d1
		lea	(line_buf,pc),a3
		move	d1,d0
		movea.l	a3,a1
@@:
		move.l	d2,(a1)+
		dbra	d0,@b
		rts

draw_backscroll:
		lea	(line_buf,pc),a0
		movea.l	(text_address,pc),a2
		move	(window_line,pc),d2
draw_backscroll_loop:
		movea.l	(a0)+,a1
		bsr	draw_line
		lea	($800,a2),a2
		dbra	d2,draw_backscroll_loop
		rts

* バックスクロールウィンドウを表示する -------- *

open_backscroll_window:
		bsr	swap_interrupt_address
		bsr	initialize_keypaste_buffer

		lea	(bitflag,pc),a1
		bset	#BACKSCR_bit,(a1)

		btst	#SUSPEND_bit,(a1)
		bne	set_text_mode

* 新規オープン時
		lea	(TEXTPAL),a0
		lea	(text_pal_buff,pc),a1
		moveq	#16/2-1,d0
@@:
		move.l	(a0)+,(a1)+		;テキストパレット待避
		dbra	d0,@b

		btst	#0,(option_m_flag,pc)
		beq	@f

		lea	(ms_ctrl_flag,pc),a0
		st	(a0)+
		move.b	(SKEYMOD),(a0)+		;skeymod_save
		IOCS	_MS_STAT
		move.b	d0,(a0)			;mscur_on_flag

		moveq	#0,d1
		IOCS	_SKEY_MOD		;ソフトキーボード/マウスカーソル消去
		IOCS	_MS_CUROF
@@:
		btst	#1,(option_m_flag,pc)
		beq	@f

		move	#0<<8+32*4,d1
		move	d1,d2			;全画面保存
		moveq	#%1100,d3
		IOCS	_TXRASCPY
@@:
		btst	#2,(option_m_flag,pc)
		bne	@f

		moveq	#2,d2			;テキスト使用状況を無視しないなら
		bsr	gm_tgusemd_orig		;使用中に設定する
@@:

* Graphic Maskのautomaskを禁止する(バックスクロール画面が
* 表示されている間、suspend/sleep中もずっと禁止したまま).
		lea	(gm_automask,pc),a0
		clr.b	(a0)
		GMcall	_GM_AUTO_STATE
		bne	@f
		swap	d0
		subq.b	#%10,d0
		bne	@f			;元から禁止状態
		st	(a0)
		GMcall	_GM_AUTO_DISABLE
@@:

set_text_mode:
		GMcall	_GM_MASK_STATE
		beq	@f
		moveq	#0,d0			;gmが常駐していないなら常にmaskなし
@@:		swap	d0
		lea	(general_work,pc),a1
		move.b	d0,(gm_maskflag-general_work,a1)

		move	(text_pal_buff,pc),d1	;パレット0(標準で黒)
		move	(text_pal_buff+3*2,pc),d2	 3(〃	 白)

*		lea	(general_work,pc),a1
		move.l	a1,-(sp)
		clr.l	-(sp)
		pea	(condrv_pal,pc)
		DOS	_GETENV
		addq.l	#12-4,sp
		move.l	d0,(sp)+
		bmi	@f

		bsr	get_palette		;文字色
		move	d1,d2
		bsr	get_palette		;背景色
@@:
		lea	(TEXTPAL+2*4),a1
		bsr	set_text_palette	;%01xx

		move	d2,d1
		addq.l	#2*4,a1
		bsr	set_text_palette	;%11xx

		bsr	draw_window

		lea	(cursor_blink_count,pc),a0
		clr	(a0)+
		move	(CSRSWITCH),(a0)	;iocs_curflg
		btst	#3,(option_m_flag,pc)
		bne	@f
		IOCS	_OS_CUROF
@@:
		.ifdef	__EMACS
			rts
		.else
			bra	clr_ins_led
		.endif

set_text_palette:
		.rept	4
		move	d1,(a1)+
		.endm
		rts

		.ifndef	__EMACS
restore_ins_led:
		bset	#LED_INS,(LEDSTAT)
		move.b	(ins_clr_flag,pc),d0
		bne	call_iocs_ledset	* INS LED は最初から点灯
clr_ins_led:
		bclr	#LED_INS,(LEDSTAT)	* INS を消す
		sne	(ins_clr_flag)
call_iocs_ledset:
		IOCS	_LEDSET
		rts
		.endif

* 環境変数からパレット値を取り出す
* in	a1.l =	環境変数
* out	d1.w =	数値
get_palette:
		moveq	#0,d0
		moveq	#0,d1
		lea	(ctype_table,pc),a0
		bra	get_palette_loop
get_palette_loop_2:
		cmpi.b	#SPACE,d0
		beq	get_palette_loop
		btst	#IS_HEX_bit,(a0,d0.w)
		beq	get_palette_end
		btst	#IS_DEC_bit,(a0,d0.w)
		bne	@f
		andi.b	#$df,d0		A-Fa-fの時は'9'の後にずらす
		subq.b	#'A'-('9'+1),d0
@@:
		andi.b	#$f,d0
		lsl	#4,d1
		or	d0,d1
get_palette_loop:
		move.b	(a1)+,d0
		bne	get_palette_loop_2
		subq.l	#1,a1
get_palette_end:
		rts

* バックログ画面塗りつぶし -------------------- *

clear_text_plane:
usereg:		.reg	d0-d7/a0-a2
		PUSH	usereg

		lea	(CRTC_R21),a0
		move	(a0),-(sp)
		bclr	#0,(a0)

		movea.l	(text_address,pc),a1
		lea	($200-$400,a1),a1	;plane 3 クリア
		bsr	fill_text_block_0

		adda.l	#$200-$20000,a1		;plane 2 塗り潰し
		moveq	#-1,d1
		bsr	fill_text_block

		move	(sp)+,(a0)

		move	(text_ras_no,pc),d1
		subi	#$0201,d1
		move	(window_line,pc),d2
		addq	#3,d2
		lsl	#2,d2
		subq	#1,d2
		moveq	#%1100,d3
		IOCS	_TXRASCPY

		POP	usereg
		rts

fill_text_block_0:
		moveq	#0,d1
fill_text_block:
	.irp	reg,d2,d3,d4,d5,d6,d7,a2
		move.l	d1,reg
	.endm
		moveq	#16-1,d0
@@:
		movem.l	d1-d7/a2,-(a1)
		dbra	d0,@b
		rts

* 上端と下端の横線を描く ---------------------- *

draw_window:
usereg:		.reg	a0-a3
		PUSH	usereg
		bsr	clear_text_plane	;バックログ画面塗りつぶし
		bsr	draw_window_tipline	;上端と下端の横線を描く
		bsr	draw_window_title
		POP	usereg
		rts

draw_window_tipline:
		bsr	get_window_bottom_tvram
		lea	(4*128,a0),a0		;下の線
		movea.l	(text_address,pc),a1
		lea	(-4*128,a1),a1		;上の線

		moveq	#WIDTH/4-1,d0
		moveq	#-1,d1
@@:
		move.l	d1,(a0)+
		move.l	d1,(a1)+
		dbra	d0,@b
		rts

draw_window_title:
		bsr	get_window_bottom_tvram
		.ifdef	__EMACS
		lea	(WIDTH-4-WINDOE_TITLE_LEN,a0),a0	;右寄せで描画
		.else
		addq.l	#2,a0
		.endif
		lea	(window_title,pc),a1
		lea	(FON_SML8),a2
		bra	1f
@@:
		lsl	#3,d0
		lea	(a2),a3
		adda.l	d0,a3
		move.b	(a3)+,(a0)+
		.irp	i,1,2,3,4,5,6,7
		move.b	(a3)+,(128*i-1,a0)
		.endm
1:
		moveq	#0,d0
		move.b	(a1)+,d0
		bne	@b
		rts

get_window_bottom_tvram:
		movea.l	(text_address,pc),a0
		moveq	#1,d0
		add	(window_line,pc),d0
		swap	d0			;
		lsr.l	#16-4-7,d0		;*16*128
		adda.l	d0,a0
		rts


* 以前のメッセージ表示行を消去する ------------ *
* in	a4.l	window_line

clear_text_raster_mesline:
		move	(a4),d1			;window_line
		add	-(a4),d1		;down_line
		addq	#2+1,d1
		lsl	#2,d1
		bra	clear_text_raster_m4

* 指定行を消去する ---------------------------- *
* in	d1.w	ラスタ番号(0～255)

clear_text_raster_m4:
		moveq	#-1,d0			;maskあり
		moveq	#4-1,d2
		bra	clear_text_raster

* 指定ラスタブロックを消去する ---------------- *
* テキスト保存モードなら裏画面から復帰する
* in	d0.b	0:GM非対応(常に全消去) -1:GM対応(マスクをかける)
*		テキスト保存モードor裏画面指定の時無意味
*	d1.w	ラスタ番号(0～255)
*	d2.w	ラスタ数-1

clear_text_raster:
usereg:		.reg	d1-d7/a0-a2
		PUSH	usereg

		tst.b	d1
		bmi	clear_text_raster_force_clear
		btst	#1,(option_m_flag,pc)
		beq	clear_text_raster_mask_clear

		move.b	d1,d0
		tas	d1			;裏画面から表にコピー
		lsl	#8,d1
		move.b	d0,d1
		addq	#1,d2
		bra	clear_text_raster_rascpy

clear_text_raster_force_clear:
		moveq	#0,d0			;裏画面はmaskしない
clear_text_raster_mask_clear:
		move.b	d1,-(sp)		;!
		move	d2,-(sp)		;!

		lea	(CRTC_R21),a0
		move	(a0),-(sp)
		move	#%1_1100_0000,(a0)

		move.b	d0,-(sp)

		addi	#($e60000+128*4)/(128*4),d1
		mulu	#128*4,d1
		movea.l	d1,a1
		bsr	fill_text_block_0	;プレーン2/3をクリアする

		move.b	(sp)+,d0
		and.b	(gm_maskflag,pc),d0
		beq	clear_text_raster_copy

		clr	(a0)			;graphic maskをかける
		moveq	#-1,d0
		moveq	#-1,d1
		moveq	#-1,d2
		moveq	#-1,d3
		moveq	#4-1,d4
@@:
		movem.l	d0-d3,(a1)
		movem.l	d0-d3,(80,a1)
		lea	(128,a1),a1
		dbra	d4,@b
clear_text_raster_copy:
		move	(sp)+,(a0)

		move	(sp)+,d2		;!
		move	(sp),d1			;!
		move.b	(sp)+,d1
		addq.b	#1,d1
clear_text_raster_rascpy:
		moveq	#%1100,d3
		IOCS	_TXRASCPY		;下に複写する

		POP	usereg
		rts

* バックスクロール画面を消去する -------------- *

close_backscroll_window:
		.ifndef	__EMACS
		lea	(mark_char_adr,pc),a0	;マーククリア
		move.l	(a0),d3
		clr.l	(a0)+			;mark_char_adr
		clr.l	(a0)+			;mark_line_adr
		.endif

		btst	#2,(option_m_flag,pc)
		bne	@f
						;テキスト使用状況を無視しないなら
		bsr	gm_tgusemd_orig_tm1	;システムで使用中に設定する
@@:
		.ifdef	__EMACS
		btst	#SUSPEND_bit,(bitflag,pc)
		bne	dont_restore_text
		bra	restore_text
		.else
		btst	#SUSPEND_bit,(bitflag,pc)
		beq	restore_text
* ctrl-undo {
		tst.l	d3
		beq	@f
		bsr	draw_backscroll		;マーク解除状態で描き直す
@@:
		bra	dont_restore_text
* }
		.endif
restore_text:
		btst	#1,(option_m_flag,pc)
		bne	restore_text_from_backside

		moveq	#-1,d0			;maskあり
		move	(down_line,pc),d1
		lsl	#2,d1
		move	(window_line,pc),d2
		addq	#3,d2
		lsl	#2,d2
		subq	#1,d2
		bra	@f
restore_text_from_backside:
		move	#32*4<<8+0,d1		;-m2指定時は裏TVRAMからコピー
		move	#32*4,d2
		moveq	#%1100,d3
		IOCS	_TXRASCPY

		moveq	#0,d0
		move	#32*4,d1
		moveq	#32*4-1,d2
@@:
		bsr	clear_text_raster	;表or裏画面消去

		lea	(ms_ctrl_flag,pc),a0
		tst.b	(a0)
		beq	mouse_ctrl_off

		clr.b	(a0)+

		moveq	#0,d1
		move.b	(a0)+,d1		;skeymod_save
		IOCS	_SKEY_MOD		;ソフトキーボードの状態を戻す

		tst.b	d1
		bmi	@f
		tst.b	(a0)			;mscur_on_flag
		beq	@f

		IOCS	_MS_CURON
@@:
mouse_ctrl_off:
		lea	(text_pal_buff,pc),a0
		lea	(TEXTPAL),a1
		moveq	#16/2-1,d0
@@:
		move.l	(a0)+,(a1)+
		dbra	d0,@b

		move.b	(gm_maskflag,pc),d0
		beq	@f
		GMcall	_GM_MASK_SET
@@:

* Graphic Maskのautomaskを禁止していた場合、許可状態に戻す.
* (suspendした場合は戻さない. sleepも同じ)
		move.b	(gm_automask,pc),d0
		beq	@f
		GMcall	_GM_AUTO_ENABLE
@@:

dont_restore_text:
		.ifndef	__EMACS
			bsr	restore_ins_led
		.endif
		btst	#3,(option_m_flag,pc)
		bne	@f
		move	(iocs_curflg,pc),(CSRSWITCH)
@@:
		lea	(bitflag,pc),a0
		bclr	#BACKSCR_bit,(a0)
		bra	swap_interrupt_address

swap_interrupt_address:
		lea	(TIMERA_VEC),a0
		lea	(vdisp_int_adr,pc),a1	;垂直同期割り込みでフックするアドレス
		bsr	swap_interrupt_address_sub

		lea	(CIRQ_VEC),a0
		lea	(ras_int_adr,pc),a1	;ラスタ割り込みでフックするアドレス
swap_interrupt_address_sub:
		move.l	(a1),d0
		beq	@f			;無効にしない

		move.l	(a0),(a1)
		move.l	d0,(a0)
@@:		rts


* バックログ内のキー入力サブルーチン ---------- *

* next-line などで一時的に短い行～長い行と移動した時、
* カーソル位置は最初の行と同じ桁に移動させる.
* この為に現在の CursorX を最初の位置として記憶する.
* ただし、next-line、previous-line、next-page、previous-page
* などは記憶している桁位置をそのままにしておく.

keyinp_loop_start:
keyinp_loop2:
		lea	(curx_save_flag,pc),a0
		tas	(a0)
		bne	@f			;桁位置はそのまま
		move	(cursorX,pc),(curx_save-curx_save_flag,a0)
@@:
keyinp_loop:
		bsr	blink_cursor
		bsr	call_orig_b_keysns
* sleep対応 {
		tst.l	d0
		bne	@f
		btst	#OPT_BG_bit,(option_flag,pc)
		beq	keyinp_loop
		lea	(bitflag,pc),a0
		tst.b	(a0)
		bmi	keyinp_loop		;help中

		bset	#SUSPEND_bit,(a0)	;バックスクロールから抜ける
		st	(sleep_flag-bitflag,a0)
		rts
@@:
* }
		cmpi	#KEY_SHIFT.shl.8,d0
		bcc	@f
		move.l	(mes_end_adr,pc),d0	;エラーメッセージを表示していたら
		beq	@f			;次のキーが入力された時に消す
		bsr	clear_message
@@:
		pea	(keyinp_loop2,pc)	以後はループする時は rts
		bsr	call_orig_b_keyinp

		move	d0,-(sp)		キーバッファがたまっていないか調べる
		bsr	call_orig_b_keysns
		move	(sp),d1
		cmp	d0,d1
		bne	@f			違うキーが押されている場合もOK

		lsr	#8,d1
		move	d1,d0
		lsr	#3,d0
		lea	(KEYSTAT),a0
		adda	d0,a0
		btst	d1,(a0)
		bne	@f			同じキーがまだ押されている

		bsr	keybuf_clear
@@:
		.ifdef	__EMACS

PREFIX_ESC:	.equ	7
PREFIX_CTRL_X:	.equ	6

keyinp_direct:
		move	(sp)+,d0
		move.b	($80e),d0
		lea	(prefix_flag,pc),a0
		or.b	(a0),d0
		KEYbtst	KEY_XF3
		beq	@f
		tas	d0		*	bset	#PREFIX_ESC,d0
@@:
		rol	#8,d0
*		cmpi.b	#KEY_SHIFT,d0
		cmpi.b	#$6d,d0
		bcc	keycheck_end		;shift/ctrl/opt.1&2 or 離した時は無視
		cmpi.b	#KEY_BREAK,d0
		bcc	@f
		cmpi.b	#KEY_XF1,d0
		bcc	keycheck_end		;xf1～5/LEDキーは無視
@@:
		clr.b	(a0)

		lea	(emacs_key_table,pc),a0
		bsr	keycheck		;braにしない事!
keycheck_end:
		rts

		.else

		moveq	#0,d0
		move.b	(sp)+,d0
		move.b	(option_o_flag,pc),d1	0:Shift 1:CTRL 2:OPT.1 3:OPT.2
		btst	d1,(SFTSTAT)
		beq	is_key_ctrl
* OPT.1系
		lea	(opt_key_table,pc),a0
		bsr	keycheck
		move.b	(option_o_flag,pc),d1
		subq.b	#2,d1
		bcc	keycheck_end		-o1,2 なら終わり
is_key_ctrl:
		SFTbtst	SFT_CTRL
		bne	check_ctrl_key
* シフト系なし
		lea	(nomal_key_table,pc),a0
		SFTbtst	SFT_SHIFT
		beq	@f
* Shift系
		lea	(shift_key_table,pc),a0
		bra	@f
* CTRL系
check_ctrl_key:
		lea	(ctrl_key_table,pc),a0
		bsr	keycheck
		lea	(ctrl_key_table_2,pc),a0
@@:
		bsr	keycheck		必ずbsr
keycheck_end:
		rts

		.endif
* 共通部分 {

keycheck:
		move	(a0)+,d1		address/flag
		.ifdef	__EMACS
			beq	visual_bell
		.else
			beq	keycheck_end
		.endif
		cmp	(a0)+,d0		keycode
		bne	keycheck

		bclr	#0,d1
		seq	(curx_save_flag)
		adda	d1,a0
		move.l	a0,(sp)			;呼び出したところには戻らなくてよい
		bra	clear_cursor

* flag = 1: カーソル位置を更新する.
* flag = 0: 現在のカーソル位置は一時的なものと見なし、curx_save は更新しない.

KEYTBL:		.macro	keycode,flag,address
		.dc	(address-($+4)).or.flag,keycode
		.endm
KEYTBL_END:	.macro
		.dc	0
		.endm

* }
		.ifdef	__EMACS

* META  C-x  0  0  | OPT.2  OPT.1  CTRL  SHIFT

emacs_key_table:
		KEYTBL	KEY_ESC		,0,key_prefix_meta
		KEYTBL	KEY_HELP	,0,key_help
		KEYTBL	KEY_HOME	,0,key_kill_condrv
		KEYTBL	KEY_UNDO	,0,key_kill_condrv
		KEYTBL	KEY_Q		,0,key_kill_condrv
		KEYTBL	KEY_CLR		,0,key_kill_condrv
		KEYTBL	KEY_←		,1,key_backward_char
		KEYTBL	KEY_B		,1,key_backward_char
		KEYTBL	KEY_→		,1,key_forward_char
		KEYTBL	KEY_F		,1,key_forward_char
		KEYTBL	KEY_↑		,0,key_previous_line
		KEYTBL	KEY_P		,0,key_previous_line
		KEYTBL	KEY_↓		,0,key_next_line
		KEYTBL	KEY_N		,0,key_next_line
		KEYTBL	KEY_R_DOWN	,0,key_scroll_down
		KEYTBL	KEY_R_UP	,0,key_scroll_up
		KEYTBL	KEY_DEL		,0,key_kill_region
		KEYTBL	KEY_CR		,0,key_yank_current_word
		KEYTBL	KEY_K		,0,key_yank_to_end_of_line
		KEYTBL	KEY_U		,0,key_yank_from_beginning_of_line
		KEYTBL	KEY_TAB		,0,key_toggle_paste_header_tab
		KEYTBL	KEY_：		,0,key_toggle_paste_header_colon
		KEYTBL	KEY_－		,0,key_toggle_paste_header_hyphen
		KEYTBL	KEY_F0		,1,key_beginning_of_buffer
		KEYTBL	KEY_F1		,1,key_end_of_buffer
		KEYTBL	KEY_／		,1,key_search_forward
		KEYTBL	KEY_F3		,1,key_search_forward
		KEYTBL	KEY_F4		,1,key_search_forward_next
SHIFT:		.equ	%0000_0001.shl.8
		KEYTBL	SHIFT+KEY_T	,1,key_beginning_of_page
		KEYTBL	SHIFT+KEY_B	,1,key_end_of_page
		KEYTBL	SHIFT+KEY_＞	,0,key_toggle_paste_header_bracket
		KEYTBL	SHIFT+KEY_／	,1,key_search_backward
		KEYTBL	SHIFT+KEY_F3	,1,key_search_backward
		KEYTBL	SHIFT+KEY_F4	,1,key_search_backward_next
		KEYTBL	SHIFT+KEY_N	,1,key_search_backward_next
.ifdef	__TAG_JMP
		KEYTBL	SHIFT+KEY_V	,1,key_tag_jump
.endif
CTRL_:		.equ	%0000_0010.shl.8
		KEYTBL	CTRL_+KEY_X	,0,key_prefix_ctrl_x
		KEYTBL	CTRL_+KEY_Z	,0,key_suspend_condrv
		KEYTBL	CTRL_+KEY_UNDO	,0,key_suspend_condrv
		KEYTBL	CTRL_+KEY_B	,1,key_backward_char
		KEYTBL	CTRL_+KEY_F	,1,key_forward_char
		KEYTBL	CTRL_+KEY_P	,0,key_previous_line
		KEYTBL	CTRL_+KEY_N	,0,key_next_line
		KEYTBL	CTRL_+KEY_A	,1,key_beginning_of_line
		KEYTBL	CTRL_+KEY_E	,1,key_end_of_line
		KEYTBL	CTRL_+KEY_R_DOWN,1,key_beginning_of_buffer_mark
		KEYTBL	CTRL_+KEY_R_UP	,1,key_end_of_buffer_mark
		KEYTBL	CTRL_+KEY_V	,0,key_scroll_up
		KEYTBL	CTRL_+KEY_SPACE	,1,key_set_mark
		KEYTBL	CTRL_+KEY_W	,0,key_kill_region
		KEYTBL	CTRL_+KEY_Y	,0,key_yank_region
		KEYTBL	CTRL_+KEY_↑	,0,key_shrink_window
		KEYTBL	CTRL_+KEY_↓	,0,key_grow_window
		KEYTBL	CTRL_+KEY_←	,0,key_move_window_up
		KEYTBL	CTRL_+KEY_→	,0,key_move_window_down
		KEYTBL	CTRL_+KEY_K	,0,key_kill_to_end_of_line
		KEYTBL	CTRL_+KEY_U	,0,key_kill_from_beginning_of_line
		KEYTBL	CTRL_+KEY_S	,1,key_isearch_forward
		KEYTBL	CTRL_+KEY_R	,1,key_isearch_backward
		KEYTBL	CTRL_+KEY_＾	,1,key_search_forward_current_word
		KEYTBL	CTRL_+KEY_＼	,1,key_search_backward_current_word
		KEYTBL	CTRL_+KEY_I	,0,key_toggle_paste_header_tab
		KEYTBL	CTRL_+KEY_BS	,0,key_toggle_buffering_mode
		KEYTBL	CTRL_+KEY_CLR	,1,key_clear_buffer
		KEYTBL	CTRL_+KEY_L	,1,key_redraw_window
		KEYTBL	CTRL_+KEY_［	,0,key_prefix_meta
		KEYTBL	CTRL_+KEY_＠	,0,key_prefix_meta	;ASCII配列用
C_X:		.equ	%0100_0000.shl.8
		KEYTBL	C_X+KEY_I	,1,key_insert_file
		KEYTBL	C_X+KEY_W	,1,key_write_file
		KEYTBL	C_X+KEY_Z	,0,key_grow_window
		KEYTBL	C_X+KEY_M	,0,key_toggle_buffer_mode
		KEYTBL	C_X+KEY_K	,0,key_kill_condrv
		.ifdef	__BUF_POS
C_X_SFT:	.equ	C_X+SHIFT
		KEYTBL	C_X_SFT+KEY_－	,0,key_buffer_position
		.endif
C_X_CTRL:	.equ	C_X+CTRL_
		KEYTBL	C_X_CTRL+KEY_I	,1,key_insert_file
		KEYTBL	C_X_CTRL+KEY_W	,1,key_write_file
		KEYTBL	C_X_CTRL+KEY_C	,0,key_kill_condrv
		KEYTBL	C_X_CTRL+KEY_Z	,0,key_shrink_window
		KEYTBL	C_X_CTRL+KEY_P	,0,key_move_window_up
		KEYTBL	C_X_CTRL+KEY_N	,0,key_move_window_down
		KEYTBL	C_X_CTRL+KEY_X	,1,key_exchange_point_and_mark
		KEYTBL	C_X_CTRL+KEY_S	,1,key_search_forward
		KEYTBL	C_X_CTRL+KEY_R	,1,key_search_backward
		KEYTBL	C_X_CTRL+KEY_M	,0,key_toggle_text_mode
META:		.equ	%1000_0000.shl.8
		KEYTBL	META+KEY_ESC	,0,key_prefix_meta_cancel
		KEYTBL	META+KEY_SPACE	,1,key_set_mark
		KEYTBL	META+KEY_．	,1,key_set_mark
		KEYTBL	META+KEY_Q	,0,key_kill_condrv
		KEYTBL	META+KEY_B	,1,key_backward_word
		KEYTBL	META+KEY_F	,1,key_forward_word
		KEYTBL	META+KEY_V	,0,key_scroll_down
		KEYTBL	META+KEY_W	,0,key_copy_region
		KEYTBL	META+KEY_R_DOWN	,0,key_slide_window_up
		KEYTBL	META+KEY_R_UP	,0,key_slide_window_down
		KEYTBL	META+KEY_N	,1,key_search_forward_next
		KEYTBL	META+KEY_I	,0,key_toggle_tab_disp
S_META:		.equ	SHIFT+META
		KEYTBL	S_META+KEY_？	,0,key_help
		KEYTBL	S_META+KEY_＜	,1,key_beginning_of_buffer_mark
		KEYTBL	S_META+KEY_＞	,1,key_end_of_buffer_mark
		KEYTBL	S_META+KEY_＊	,0,key_toggle_cr_disp
C_META:		.equ	CTRL_+META
		KEYTBL	C_META+KEY_［	,0,key_prefix_meta_cancel
		KEYTBL	C_META+KEY_＠	,0,key_prefix_meta_cancel	;ASCII配列用
		KEYTBL	C_META+KEY_G	,1,key_goto_mark
		KEYTBL_END

key_prefix_meta:
		lea	(prefix_meta_mes,pc),a1
		moveq	#PREFIX_ESC,d0
		bra	@f
key_prefix_ctrl_x:
		lea	(prefix_ctrlx_mes,pc),a1
		moveq	#PREFIX_CTRL_X,d0
@@:
		bsr	print_message
		lea	(prefix_flag,pc),a0
		bset	d0,(a0)
key_prefix_meta_cancel:
		rts

		.else
nomal_key_table:
		KEYTBL	KEY_ESC		,0,key_kill_condrv
		KEYTBL	KEY_HOME	,0,key_kill_condrv
		KEYTBL	KEY_UNDO	,0,key_kill_region
		KEYTBL	KEY_R_UP	,0,key_scroll_up
		KEYTBL	KEY_R_DOWN	,0,key_scroll_down
		KEYTBL	KEY_A		,1,key_backward_word
		KEYTBL	KEY_F		,1,key_forward_word
		KEYTBL	KEY_↑		,0,key_previous_line
		KEYTBL	KEY_↓		,0,key_next_line
		KEYTBL	KEY_←		,1,key_backward_char
		KEYTBL	KEY_→		,1,key_forward_char
		KEYTBL	KEY_M		,0,key_mark_change_led
		KEYTBL	KEY_INS		,0,key_mark_dont_change_led
		KEYTBL	KEY_K		,0,key_yank_to_end_of_line
		KEYTBL	KEY_O		,0,key_kill_region
		KEYTBL	KEY_DEL		,0,key_kill_region
		KEYTBL	KEY_CR		,0,key_yank
		KEYTBL	KEY_ENTER	,0,key_yank
		KEYTBL	KEY_U		,0,key_yank_from_beginning_of_line
		KEYTBL	KEY_／		,1,key_search_forward
		KEYTBL	KEY_F3		,1,key_search_forward
		KEYTBL	KEY_N		,1,key_search_forward_next
		KEYTBL	KEY_F4		,1,key_search_forward_next
		KEYTBL	KEY_HELP	,0,key_help
		KEYTBL	KEY_：		,0,key_toggle_paste_header_colon
		KEYTBL	KEY_－		,0,key_toggle_paste_header_hyphen
		KEYTBL	KEY_TAB		,0,key_toggle_paste_header_tab
		KEYTBL	KEY_T		,1,key_beginning_of_buffer
		KEYTBL	KEY_F0		,1,key_beginning_of_buffer
		KEYTBL	KEY_B		,1,key_end_of_buffer
		KEYTBL	KEY_F1		,1,key_end_of_buffer
		KEYTBL	KEY_L		,0,key_set_label
		KEYTBL	KEY_Q		,0,key_toggle_buffer_mode
*		KEYTBL_END
ctrl_key_table_2:				* CTRL を押しても押さなくても同じもの
		KEYTBL	KEY_W		,0,key_move_window_up
		KEYTBL	KEY_Z		,0,key_move_window_down
		KEYTBL	KEY_E		,0,key_previous_line
		KEYTBL	KEY_X		,0,key_next_line
		KEYTBL	KEY_D		,1,key_forward_char
		KEYTBL	KEY_S		,1,key_backward_char
		KEYTBL	KEY_P		,0,key_yank
		KEYTBL_END
opt_key_table:
		KEYTBL	KEY_←		,0,key_move_window_up
		KEYTBL	KEY_→		,0,key_move_window_down
		KEYTBL	KEY_UNDO	,0,key_suspend_condrv
		KEYTBL	KEY_R_UP	,0,key_slide_window_down
		KEYTBL	KEY_R_DOWN	,0,key_slide_window_up
		KEYTBL	KEY_↑		,0,key_shrink_window
		KEYTBL	KEY_↓		,0,key_grow_window
		KEYTBL_END
ctrl_key_table:
		KEYTBL	KEY_［		,0,key_kill_condrv
		KEYTBL	KEY_R		,0,key_scroll_down
		KEYTBL	KEY_C		,0,key_scroll_up
		KEYTBL	KEY_T		,1,key_beginning_of_page
		KEYTBL	KEY_B		,1,key_end_of_page
		KEYTBL	KEY_A		,1,key_beginning_of_line
		KEYTBL	KEY_F		,1,key_end_of_line
		KEYTBL	KEY_K		,0,key_kill_to_end_of_line
		KEYTBL	KEY_U		,0,key_kill_from_beginning_of_line
		KEYTBL	KEY_N		,1,key_search_backward_next
		KEYTBL	KEY_＠		,1,key_write_file
		KEYTBL	KEY_J		,0,key_help
		KEYTBL	KEY_］		,0,key_help
		KEYTBL	KEY_I		,0,key_toggle_paste_header_tab
		KEYTBL	KEY_Y		,1,key_insert_file
		KEYTBL	KEY_Q		,0,key_toggle_text_mode
		KEYTBL	KEY_＾		,1,key_search_forward_current_word
		KEYTBL	KEY_＼		,1,key_search_backward_current_word
		KEYTBL	KEY_BS		,0,key_toggle_buffering_mode
		KEYTBL	KEY_CLR		,1,key_clear_buffer
		KEYTBL_END
shift_key_table:
		KEYTBL	KEY_／		,1,key_search_backward
		KEYTBL	KEY_F3		,1,key_search_backward
		KEYTBL	KEY_F4		,1,key_search_backward_next
		KEYTBL	KEY_N		,1,key_search_backward_next
		KEYTBL	KEY_．		,0,key_toggle_paste_header_bracket
		KEYTBL	KEY_7		,1,key_jump_label
		KEYTBL_END

		.endif

* ペーストヘッダ変更
key_toggle_paste_header_tab:
		moveq	#TAB,d0
		bra	@f
key_toggle_paste_header_hyphen:
		moveq	#'-',d0
		bra	@f
key_toggle_paste_header_colon:
		moveq	#':',d0
		bra	@f
key_toggle_paste_header_bracket:
		move.b	(default_paste_header,pc),d0
@@:
		lea	(paste_header,pc),a0
		cmp.b	(a0),d0
		bne	@f
		moveq	#0,d0			既に設定されていたら取り消し
@@:
		move.b	d0,(a0)
		bra	display_system_status

* マーク -------------------------------------- *

		.ifndef	__EMACS
key_mark_change_led:
		bchg	#LED_INS,(LEDSTAT)	* INS の LED 状態を反転
		IOCS	_LEDSET
key_mark_dont_change_led:
		move.l	(mark_char_adr,pc),d0
		beq	key_set_mark
clear_mark_and_redraw:
		bsr	clear_mark
		bra	draw_backscroll
		.endif

clear_mark:
		lea	(mark_char_adr,pc),a0
		clr.l	(a0)+
		clr.l	(a0)
		.ifdef	__EMACS
			rts
		.else
			bclr	#LED_INS,(LEDSTAT)
			bra	call_iocs_ledset
		.endif

key_set_mark:
		.ifdef	__EMACS
			lea	(set_mark_mes,pc),a1
			bsr	print_message
		.endif
key_set_mark_quiet:
		bsr	get_cursor_line_buffer
		bpl	@f

		movea.l	(buffer_now,a6),a1	;バッファが空ならダミーを設定する
@@:
		lea	(mark_line_adr,pc),a0
		move.l	a1,(a0)
		adda	(cursorXbyte,pc),a1
		addq.l	#1,a1
		EndChk2	a1
		move.l	a1,-(a0)		;mark_char_adr

		.ifndef	__EMACS
		bra	draw_backscroll

		.else
goto_mark_end:
		rts

key_exchange_point_and_mark:
		move.l	(mark_line_adr,pc),d1
		beq	no_mark_error
		move.l	(mark_char_adr,pc),d2
		bsr	key_set_mark_quiet
key_goto_mark_jump:
		movea.l	d2,a1
		sub.l	d1,d2
		subq	#1,d2
		bsr	search_zenkaku_check	;桁位置(d3)の収得のみ
		bra	search_found_scroll

key_goto_mark:
		move.l	(mark_line_adr,pc),d1
		beq	no_mark_error
		move.l	(mark_char_adr,pc),d2
		bra	key_goto_mark_jump

		.endif

* バックスクロール画面拡大・縮小 -------------- *

* ~DOWN : バックログ画面を下に広げて一行増やす
key_grow_window:
		move.b	(bitflag,pc),d0		HELPMODE_bit
		bmi	grow_window_end

		lea	(down_line,pc),a4
		move	(a4)+,d0		下に移動した行数
		add	(window_line-(down_line+2),a4),d0
		cmpi	#28,d0
		bcc	grow_window_end

		lsl	#2,d0			d0*4+(12-1) -> d0*4+(16-1)
		move.b	d0,-(sp)	*	move.b	d0,d1
		move	(sp)+,d1	*	lsl	#8,d1
		move.b	d0,d1
		addi	#(12-1).shl.8+(16-1),d1
		moveq	#(2+4),d0
		bsr	rascpy_down

		addq	#1,(a4)			;window_line
		bsr	reset_line_address_buf
		lea	(line_buf,pc),a3

		move	(a4),d0
		bsr	draw_line_d0
		lsl	#2,d0
		tst.l	(a3,d0.w)
		bmi	key_move_window_up
grow_window_end:
shrink_window_end:
		rts

* ~UP : バックログ画面を上に狭めて一行減らす
key_shrink_window:
		move.b	(bitflag,pc),d0		;HELPMODE_bit
		bmi	shrink_window_end

		lea	(window_line,pc),a4
		move	(a4),d0
		cmpi	#4,d0
		bcs	shrink_window_end

		lea	(cursorY,pc),a1
		cmp	(a1),d0
		bne	shrink_window_cursor_fixed

		lea	(line_buf,pc),a0	;カーソルが最下行にある場合は
		lea	(4,a0),a2		;スクロールアップする
		subq	#1,d0
@@:
		move.l	(a2)+,(a0)+
		dbra	d0,@b
		subq	#1,(a1)			cursorY
		bsr	rascpy_up_all
shrink_window_cursor_fixed:
		lea	(line_buf,pc),a3	;メッセージ表示行を上に移動する
		move	(a4),d0
		subq	#1,(a4)			;window_line
		lsl	#2,d0
		st	(a3,d0.w)
		move	d0,d1
		addq	#4,d1
		lsl	#8,d1
		move.b	d0,d1
		moveq	#2+4,d0
		bsr	rascpy_up

		bra	clear_text_raster_mesline

* バックスクロールウィンドウの移動 ------------ *

* ~ROLLDOWN : バックログ画面を上に移動する
key_slide_window_up:
		lea	(down_line,pc),a4
		move	(a4)+,d1
		beq	slide_window_up_end	;これ以上移動できない

		move	#$fdfa,d1		;@-2 -> @-2-4
		move	(a4),d0			;window_line
		addq	#2+1,d0
		bsr	rascpy_up_shl2

		lea	(text_address,pc),a0
		subi.l	#$800,(a0)+
		subi	#$404,(a0)+
		subq	#1,(a0)+

		bra	clear_text_raster_mesline	;以前の最下行を消去する

* ~ROLLUP : バックログ画面を下に移動する
key_slide_window_down:
		move	(down_line,pc),d3
		move	(window_line,pc),d0
		add	d3,d0
		cmpi	#28,d0
		bcc	slide_window_down_end	;これ以上移動できない

		addq	#3,d0
		lsl	#2,d0
		subq	#1,d0
		move.b	d0,-(sp)
		move	(sp)+,d1
		addq	#4,d0
		move.b	d0,d1
		move	(window_line,pc),d0
		addq	#3,d0
		lsl	#2,d0			;(行数+2)*4
		bsr	rascpy_down

		moveq	#0,d1
		move.b	(text_ras_no,pc),d1
		subq	#2,d1
		bsr	clear_text_raster_m4	;以前の先頭行を消去する

		lea	(text_address,pc),a0
		addi.l	#$800,(a0)+
		addi	#$404,(a0)+
		addq	#1,(a0)+
slide_window_up_end:
slide_window_down_end:
write_cancel:
		rts

* --------------------------------------------- *

* ^@ : ファイル書き出し
key_write_file:
		lea	(write_file_prompt,pc),a1
		bsr	input_string
		beq	write_cancel
		bsr	unfold_home
		bsr	check_diskready
		bmi	disk_notready_error

		move	#1<<ARCHIVE,-(sp)
		move.l	a1,-(sp)
		DOS	_NEWFILE
		addq.l	#6,sp
		move.l	d0,d4
		bpl	write_file_status_check

		move	#WOPEN,-(sp)
		move.l	a1,-(sp)
		DOS	_OPEN
		addq.l	#6,sp
		move.l	d0,d4
		bmi	fileopen_error

		move	#2,-(sp)		書き込みオープンした場合は末尾にアペンド
		clr.l	-(sp)
		move	d4,-(sp)
		DOS	_SEEK
		addq.l	#8,sp
write_file_status_check:
		moveq	#7,d1
		bsr	is_file_io_enable
		bne	filewrite_disable

		move.l	(mark_char_adr,pc),d0
		bne	write_file_mark_area

		moveq	#0,d0
		moveq	#0,d2
		movea.l	(buffer_old,a6),a0	;マークなしの時は最初から最後まで
		addq.l	#1,a0
		EndChk	a0
		move.b	(a0)+,d2
		EndChk	a0
		movea.l	(buffer_now,a6),a1
		tst.b	(a1)+
		beq	@f

		movea.l	(buffer_write,a6),a1
		addq.l	#2,a1			改行直後でない場合は擬似的な次の行を想定する
@@:
		bra	write_file_loop_1

write_file_mark_area:
		bsr	get_mark_area
		beq	close_filehandle_d4
* d0	次に転送する桁位置
* d1	バッファ書き込みバイト数
* d2	現在行の桁数
* a0	バッファ注目点
* a1	終了アドレス
write_file_loop_1:
		lea	(io_buffer,pc),a2
		moveq	#0,d1
write_file_loop_2:
		cmp	d0,d2
		bne	@f
		addq.l	#1,a0			;次の行
		EndChk	a0
		moveq	#0,d0
		moveq	#0,d2
		move.b	(a0)+,d2
		EndChk	a0
@@:
		cmpa.l	a0,a1
		beq	write_file_end
		move.b	(a0)+,d3
		EndChk	a0
		cmpi.b	#CR,d3
		bne	@f
		moveq	#LF,d3
@@:
		move.b	d3,(a2)+
		addq	#1,d0
		addq	#1,d1
		cmpi	#IOBUFSIZE,d1
		bne	write_file_loop_2
		bsr	write_file_sub
		bra	write_file_loop_1

write_file_end:
		tst	d1
		beq	@f
		bsr	write_file_sub
@@:
		.ifndef	__EMACS
			bsr	clear_mark_and_redraw
		.endif
		bra	close_filehandle_d4

write_file_sub:
		move.l	d0,-(sp)
		move.l	d1,-(sp)
		pea	(io_buffer,pc)
		move	d4,-(sp)
		DOS	_WRITE
		lea	(10,sp),sp
		move.l	(sp)+,d0
		rts

* 遂次検索 ------------------------------------ *

		.ifdef	__EMACS

wait_vdisp_vsync:
		btst	#4,(MFP_GPIP)
		beq	wait_vdisp_vsync
wait_vsync:
		btst	#4,(MFP_GPIP)
		bne	wait_vsync
		rts

visual_bell:
		lea	(2*(4+4)+TEXTPAL),a1
		move.l	-(a1),-(sp)		* 背景色待避
		move.l	-(a1),-(sp)
		move	(2*(12-4),a1),d1	* 文字色

		bsr	wait_vsync
		bsr	set_text_palette
		subq.l	#4*2,a1

		bsr	wait_vdisp_vsync

		move.l	(sp)+,(a1)+		* 背景色復帰
		move.l	(sp)+,(a1)+
		rts

call_dos_keyctrl_md0:
		moveq	#0,d0
call_dos_keyctrl:
		move	d0,-(sp)		* 0/1
		DOS	_KEYCTRL
		move	d0,(sp)+
		rts

		.offset	0
isch_strptr:	.ds.l	1
isch_direct:	.ds.b	1			;$00:forward $ff:backward
isch_inpmod:	.ds.b	1			;$00:通常 $ff:C-q/C-vの直後

isch_save_line:	.ds.l	1			;検索開始前のカーソル位置
isch_save_cx:	.ds	1
isch_save_cxb:	.ds	1
isch_save_cy:	.ds	1
sizeof_isch:
		.text

* 前方遂次検索
key_isearch_forward:
		moveq	#0,d0
		bra	@f
* 後方遂次検索
key_isearch_backward:
		move	#$ff<<8,d0
@@:
		move	(cursorY,pc),-(sp)
		move.l	(cursorX,pc),-(sp)	;cursorX/Xbyte
		move.l	(line_buf,pc),-(sp)

		move	d0,-(sp)		;isch_direct/inpmod
		clr.l	-(sp)			;isch_strptr

* 再定義可能なキーの内容を変更する
		pea	(fnckey_buf,pc)
		clr	-(sp)			収得
		DOS	_FNCKEY
		addq.l	#6,sp

		lea	(ise_fnc_tbl,pc),a0
		bra	isearch_setfnc
isearch_setfnc_loop:
		move.l	a0,-(sp)
		move	d0,-(sp)
		DOS	_FNCKEY
		addq.l	#6,sp
@@:
		tst.b	(a0)+
		bne	@b
isearch_setfnc:
		move	#$01_00,d0		設定
		move.b	(a0)+,d0
		bne	isearch_setfnc_loop

		bsr	fep_enable

* general_work:	.dc.b	'isearch ['
*		.dc.b	前回検索文字列
*		.dc.b	']:'
* (isch_strptr,sp) ->
*		.dc.b	検索文字列

		lea	(general_work,pc),a1
		clr.l	(search_char_adr-general_work,a1)
		lea	(isearch_mes_1,pc),a0	;"isearch ["
		bsr	str_copy
		lea	(isearch_string_buf,pc),a0
		bsr	str_copy
		lea	(isearch_mes_2,pc),a0	;"]:"
		bsr	str_copy
		move.l	a1,(isch_strptr,sp)	;検索文字列バッファのアドレス

isearch_redraw_loop:
		lea	(general_work,pc),a1
		bsr	print_message
		bra	isearch_loop
isearch_bell:
		bsr	visual_bell
isearch_loop:
		bsr	blink_cursor
		moveq	#1,d0
		bsr	call_dos_keyctrl
		beq	isearch_loop
		bsr	call_dos_keyctrl_md0
		beq	isearch_loop		念の為

		bsr	clear_cursor
*** 制御記号の検査 ***
		move.b	d0,d1
		addq.b	#1,d1
		beq	isearch_fnckey		カーソル等だった場合(C-qより先に見る)

		tst.b	(isch_inpmod,sp)
		bne	isearch_next_char	C-q,C-vの直後

		lea	(isearch_table,pc),a0
@@:
		move	(a0)+,d1
		beq	@f
		cmp	(a0)+,d0
		bne	@b
		adda	d1,a0
		jmp	(a0)
@@:
		cmpi	#$20,d0			バインドされていない制御記号が入力された
		bcs	isearch_exit		時は遂次検索から抜けて評価する
isearch_next_char:
		clr.b	(isch_inpmod,sp)
		movea.l	(isch_strptr,sp),a0
		bsr	get_isearch_strlen

		lea	(ctype_table,pc),a2
		BRA_IF_MB (a2,d0.w),isearch_mb
* isearch_single_byte_code:
		tst.b	d0
		bmi	isearch_sb		半角片仮名
		KEYbtst	KEY_XF3
		beq	isearch_sb
		cmpi.b	#$40,d0
		bmi	@f
		andi.b	#$1f,d0
@@:
		bra	isearch_exit		Meta+??
isearch_mb:
		lsl	#8,d0
		move	d0,-(sp)
		bsr	call_dos_keyctrl_md0	2byte目を取り除く
		or	(sp)+,d0		High/Low
isearch_mb_2:
		cmpi	#GETSMAX-1,d1
		bcc	isearch_bell

		move	d0,-(sp)		上位バイト
		move.b	(sp)+,(a0)+
		tst.b	d0
		bne	isearch_sb_2

		clr.b	-(a0)			$??_00は無視
		bra	isearch_loop
isearch_sb:
		cmpi	#GETSMAX,d1
		bcc	isearch_bell
isearch_sb_2:
		move.b	d0,(a0)+		下位バイト
		clr.b	(a0)

		bsr	print_message_cont
isearch_search_next0:
		lea	(bitflag,pc),a1		;今度の検索はカーソル位置若しくは
		bset	#ISEARCH_bit,(a1)	;見つかった文字列の先頭から開始する
isearch_search_next:
		movea.l	(isch_strptr,sp),a1
		tst.b	(a1)
		bne	@f
		lea	(isearch_string_buf,pc),a1
@@:
		bsr	make_search_work_a1
		beq	isearch_loop		;検索文字列が空
		tst.b	(isch_direct,sp)
		bne	isearch_search_backward

		bsr	i_search_forward_main
		bra	@f
isearch_search_backward:
		bsr	i_search_backward_main
@@:
		bmi	isearch_bell		;検索失敗
		bra	isearch_loop

;任意設定が可能なキーの処理
isearch_fnckey:
		bsr	call_dos_keyctrl_md0
		beq	isearch_loop
		cmpi	#11,d0
		bhi	isearch_loop
		add	d0,d0

		move.b	(SFTSTAT),d1
		KEYbtst	KEY_XF3
		beq	@f

		lea	(key_slide_window_down,pc),a0
		subq	#4,d0			;2/4のみbindされている
		bhi	isearch_loop
		bmi	isearch_fnckey_jump
		lea	(key_slide_window_up,pc),a0
		bra	isearch_fnckey_jump
@@:
		lea	(isearch_fnckey_normal,pc),a0
		bclr	#SFT_CTRL,d1
		beq	@f
		lea	(isearch_fnckey_ctrl,pc),a0
@@:
		move	(-2,a0,d0.w),d0
		beq	isearch_loop
		adda	d0,a0
isearch_fnckey_jump:
		tst.b	d1
		bne	isearch_loop
isearch_fnckey_exit:
		movea.l	(isch_strptr,sp),a1
		lea	(sizeof_isch,sp),sp
		move.l	a0,-(sp)
		bra	isearch_end

isearch_fnckey_normal:
@@:		.dc	key_scroll_up-@b	ROLL UP
		.dc	key_scroll_down-@b	ROLL DOWN
		.dc	key_kill_region-@b	DEL
		.dc	key_previous_line-@b	↑
		.dc	key_backward_char-@b	←
		.dc	key_forward_char-@b	→
		.dc	key_next_line-@b	↓
		.dc	0			CLR
		.dc	key_help-@b		HELP
		.dc	key_kill_condrv-@b	HOME
		.dc	key_kill_condrv-@b	UNDO

isearch_fnckey_ctrl:
@@:		.dc	key_end_of_buffer_mark-@b	ROLL UP
		.dc	key_beginning_of_buffer_mark-@b	ROLL DOWN
		.dc	0			DEL
		.dc	key_shrink_window-@b	↑
		.dc	key_move_window_up-@b	←
		.dc	key_move_window_down-@b	→
		.dc	key_grow_window-@b	↓
		.dc	key_clear_buffer-@b	CLR
		.dc	0			HELP
		.dc	0			HOME
		.dc	key_suspend_condrv-@b	UNDO

ISETBL:		.macro	address,char
		.dc	address-($+4),CTRL+char
		.endm

isearch_table:
		ISETBL	isearch_next_char	,'I'	* TAB
		ISETBL	isearch_next_char	,'M'	* CR
		ISETBL	isearch_lf		,'J'	* LF(-> CR)

		ISETBL	isearch_meta_end	,'['	* ESC
		ISETBL	isearch_ctrl_g_end	,'G'
		ISETBL	isearch_ctrl_s		,'S'
		ISETBL	isearch_ctrl_r		,'R'
		ISETBL	isearch_backspace_b	,'B'
		ISETBL	isearch_backspace_h	,'H'
		ISETBL	isearch_ctrl_f		,'F'
		ISETBL	isearch_input_ctrlcode	,'V'
		ISETBL	isearch_input_ctrlcode	,'Q'
		.dc	0

isearch_lf:
		moveq	#CR,d0			改行と見なす
		bra	isearch_next_char

isearch_ctrl_s:
		moveq	#0,d0
		bra	@f
isearch_ctrl_r:
		moveq	#-1,d0
@@:		cmp.b	(isch_direct,sp),d0
		beq	isearch_search_next	;次/前の文字から検索
		move.b	d0,(isch_direct,sp)
		bra	isearch_search_next0	;検索文字列の末尾/先頭に移動

isearch_input_ctrlcode:
		st	(isch_inpmod,sp)
		bra	isearch_loop

isearch_backspace_h:
		SFTbtst	SFT_CTRL
		beq	@f
		KEYbtst	KEY_H
		bne	@f
		KEYbtst	KEY_BS
		lea	(key_toggle_buffering_mode,pc),a0
		bne	isearch_fnckey_exit	;C-bs
@@:
isearch_backspace_b:
		movea.l	(isch_strptr,sp),a0
		moveq	#0,d0
		move.b	(a0)+,d0
		beq	isearch_loop		検索文字列は空

		lea	(ctype_table,pc),a1
@@:
		tst.b	(a1,d0.w)		;btst #IS_MB_bit,(a1,d0.w)
		smi	d1			;sne d1
		ext	d1			半角=$0000,全角=$ffff
		suba	d1,a0			全角なら1byte進める
		move.b	(a0)+,d0
		bne	@b

		clr.b	(-2,a0,d1.w)		最後の文字を消す
		bsr	clear_message
		bra	isearch_redraw_loop

isearch_ctrl_f:
		movea.l	(isch_strptr,sp),a0
		tst.b	(a0)			;検索文字列がまだ入力されていないなら
		beq	pickup_char_cur		;カーソル位置から収得
		move.l	(search_char_adr,pc),d0
		beq	isearch_bell		;検索失敗時は取り込めない

		move	(search_xbyte,pc),d2	;検索成功時は見つかった
		move	(search_x,pc),d3	;文字列の末尾から取り込む
		movea.l	d0,a1
		suba	d2,a1
		subq.l	#1,a1
		TopChk	a1
		moveq	#0,d1
		move.b	(a1),d1			;行のバイト数

		movea.l	d0,a1
		lea	(case_table,pc),a2
pickup_char_loop:
		bsr	get_char
		moveq	#0,d4
		move.b	(a0)+,d4
		beq	pickup_char_exec
		tst	d0
		bmi	pickup_char_cmp_mb

		move.b	(a2,d4.w),d4		-x オプションによっては大文字小文字を
		cmp.b	(a2,d0.w),d4		同一視して比較する
		bra	@f
pickup_char_cmp_mb:
		lsl	#8,d4			2bytes文字
		move.b	(a0)+,d4
		cmp	d0,d4			;1998/02/28 この比較は不要になったと
@@:		bne	isearch_bell		;思うが、一応残しておく
		cmp	d1,d2
		bne	pickup_char_loop

		addq.l	#1,a1
		EndChk	a1
		move.b	(a1)+,d1		;行のバイト数
		EndChk	a1
		moveq	#0,d2			;cursorX
		moveq	#0,d3			;cursorXbyte
		bra	pickup_char_loop

pickup_char_cur:
		lea	(line_buf,pc),a1
		movem	(cursorX,pc),d2/d3/d4
		lsl	#2,d4			;cursorY
		movea.l	(a1,d4.w),a1
		moveq	#0,d1
		move.b	(a1)+,d1		;注目行の文字数
		adda	d3,a1
		EndChk	a1
		bsr	get_char
		tst	d0
		beq	isearch_bell
pickup_char_exec:
		movea.l	(isch_strptr,sp),a0
		bsr	get_isearch_strlen
		tst	d0
		bmi	isearch_mb_2
		bne	isearch_sb
*isearch_ctrl_f_end:
		bra	isearch_loop

* 検索文字列の各種情報を得る
* in	a0.l	文字列
* out	d1.l	文字数
*	a0.l	文字列末尾(NUL)
*	a1.l	〃(print_message_cont用)

get_isearch_strlen:
		move.l	a0,-(sp)
@@:		tst.b	(a0)+
		bne	@b
		subq.l	#1,a0
		move.l	a0,d1
		sub.l	(sp)+,d1
		lea	(a0),a1
		rts

isearch_exit:
		movea.l	(isch_strptr,sp),a1
		lea	(sizeof_isch,sp),sp

		lea	(ctrl2scan_table,pc),a0
		move.b	(a0,d0.w),-(sp)
		pea	(keyinp_direct,pc)
		bra	isearch_end

isearch_ctrl_g_end:
		movea.l	(isch_save_line,sp),a0
		bsr	reset_line_address_buf_2

		lea	(cursorX,pc),a0
		move.l	(isch_save_cx,sp),(a0)+	;cusorX/Xbyte
		move	(isch_save_cy,sp),(a0)	;cusorY
		bsr	draw_backscroll
isearch_meta_end:
		movea.l	(isch_strptr,sp),a1
		lea	(sizeof_isch,sp),sp
		bra	isearch_end

isearch_end:
		tst.b	(a1)			検索文字列を保存する
		beq	isearch_skip_save_str
		lea	(isearch_string_buf,pc),a0
@@:		move.b	(a1)+,(a0)+
		bne	@b
isearch_skip_save_str:

* 再定義可能なキーの内容を戻す
		pea	(fnckey_buf,pc)
		move	#$01_00,-(sp)		設定
		DOS	_FNCKEY
		addq.l	#6,sp

		bsr	fep_disable
		bsr	clear_cursor
		bra	clear_message

		.endif

* 検索 ---------------------------------------- *

* C-^
key_search_forward_current_word:
		bsr	readline_yank_current_word
		bra	key_search_forward
* ↓検索／次検索
key_search_forward:
		lea	(search_forward_mes,pc),a1
		bsr	input_string
		beq	search_forward_end
		bsr	copy_search_str
key_search_forward_next:
		bsr	make_search_work
		beq	search_forward_end
		lea	(searching_mes,pc),a1
		bsr	print_message
		bsr	search_forward_main
search_found_or_not:
		lea	(not_found_mes,pc),a1
		bmi	print_message
		bra	clear_message

readline_yank_current_word:
		bsr	get_cursor_line_buffer
		bmi	key_kill_condrv

		moveq	#GETSMAX,d2
		lea	(RL_PASTEBUF,pc),a2
		bsr	yank_current_word_sub
		lea	(RL_PASTEBUF,pc),a0
		move.l	a0,(paste_pointer-RL_PASTEBUF,a0)
search_forward_end:
		rts

* 汎用バッファから検索文字列用バッファに待避しておく
copy_search_str:
		lea	(search_string_buf,pc),a0
@@:		move.b	(a1)+,(a0)+
		bne	@b
		rts

* in	a1.l	検索文字列
* out	d7.l	最初の1バイト(2バイト文字の場合は上位バイトのみ)
*	a0.l	case_table
*	a3.l	line_buf
*	a5.l	(a5):		検索文字列

make_search_work:
		lea	(search_string_buf,pc),a1
make_search_work_a1:
		lea	(case_table,pc),a0
		lea	(line_buf,pc),a3
		moveq	#0,d0
		moveq	#0,d7
		lea	(ctype_table,pc),a5
		lea	(search_string,pc),a2

		move.b	(a1)+,d7		最初の１文字
		beq	make_search_work_end
		move.b	(a0,d7.w),d7		あらかじめ大文字化しておく
		BRA_IF_MB (a5,d7.w),make_search_str_mb_low

@@:		move.b	(a1)+,d0
		BRA_IF_MB (a5,d0.w),make_search_str_mb_high
		move.b	(a0,d0.w),(a2)+
make_search_str_next:
		bne	@b
@@:		moveq	#1,d0
make_search_work_end:
		lea	(search_string,pc),a5
		rts

make_search_str_mb_high:
		move.b	d0,(a2)+
		beq	@b
make_search_str_mb_low:
		move.b	(a1)+,(a2)+		下位バイト(大文字化しない)
		bra	make_search_str_next

* ↓検索メイン処理
* in	d7.l	最初の1バイト(2バイト文字の場合は上位バイトのみ)
*	a0.l	case_table
*	a3.l	line_buf
*	a5.l	(a5):		検索文字列
* out	d0.l	0:検索成功 -1:失敗
* 備考:
*	i_search_forward_mainでは
*	成功すればsearch_char_adr、search_x、search_xbyteがセットされる.
*	失敗すればsearch_char_adrがクリアされる.

i_search_forward_main:
		not.l	d7			;上位ワードが負なら遂次検索モード
		not	d7
		bsr	get_isearch_start
		bne	@f
search_forward_main:
		bsr	search_sub_getcur
		bmi	search_not_found
@@:
		tst.b	(a1)
		beq	search_not_found

		.ifdef	__EMACS
		bclr	#ISEARCH_bit,(bitflag-case_table,a0)
		beq	@f

		subq.l	#1,a1
		subq	#1,d2
@@:
		.endif
search_forward_skip_lowbyte:
		moveq	#0,d3
search_forward_not_match:
		addq.l	#1,a1			;次の文字から調べる
		EndChk	a1
		addq	#1,d2
		cmp	d1,d2			;桁数
		bne	search_forward_char

		tst.b	(a1)+
		beq	search_not_found	;バッファ末まで見つからなかった
		EndChk	a1
		moveq	#0,d2
		moveq	#0,d1
		move.b	(a1)+,d1		;桁数
		beq	search_not_found
		EndChk	a1
search_forward_char:
		lea	(ctype_table,pc),a2
		BRA_IF_MB (a2,d3.w),search_forward_skip_lowbyte	;さっき比較したのが2バイト文字なら下位バイトを飛ばす
		move.b	(a1),d3
		cmp.b	(a0,d3.w),d7		;大文字化(-x 指定時)して比較
		bne	search_forward_not_match
		bsr	search_sub
		bne	search_forward_not_match	注目位置からは一致しない

		bsr	search_zenkaku_check	;桁位置(d3)の収得のみ
		lea	(search_char_adr,pc),a2
		move.l	a1,(a2)+		;search_char_adr
		move	d3,(a2)+		;search_x
		move	d2,(a2)+		;search_xbyte

;i-searchならカーソルは検索文字列の末尾に移動する
		tst.l	d7
		bpl	isearch_move_skip

		lea	(-1,a1),a2
		suba	d2,a2
		TopChk	a2
		move.b	(a2),d1			;行のバイト数
isearch_move_loop:
		bsr	get_char		;一文字分カーソルを進める
		cmp	d1,d2
		bne	@f

		tst.b	(a1)
		beq	isearch_move_skip	;バッファ末尾なら次の行には行かない

		addq.l	#1,a1
		EndChk	a1
		move.b	(a1)+,d1		;行のバイト数
		EndChk	a1
		moveq	#0,d2			;cursorXbyte
		moveq	#0,d3			;cursorX
@@:
		tst	d0
		bpl	@f
		addq.l	#1,a5			;2バイト文字
@@:		tst.b	(a5)+
		bne	isearch_move_loop	;検索文字列の末尾まで移動する
isearch_move_skip:

search_found_scroll:
		subq.l	#1,a1
		suba	d2,a1
		TopChk	a1
jump_scroll:
		lea	(line_buf,pc),a3
		movea.l	(a3),a0
		move	(window_line,pc),d0
@@:
		tst.b	(a3)			;このチェックは redraw-window で必要
		bmi	@f			;そうでない場合も念の為
		cmpa.l	(a3)+,a1
		dbeq	d0,@b
		beq	jump_scroll_same_page	見つけた行が現在表示中ならスクロールしない
@@:
		movea.l	a1,a0			見つけた行を最上段に表示

		move	(window_line,pc),d1	;センタリング
		lsr	#1,d1
		subq	#1,d1			;表示行数の半分だけ下にずらす
		moveq	#0,d0
jump_scroll_center_loop:
		lea	(-1,a0),a3
		TopChk	a3
		move.b	(a3),d0
		beq	jump_scroll_center_loop_end
		suba	d0,a0			;前の行に移動
		subq.l	#1+1,a0
		TopChk	a0
		dbra	d1,jump_scroll_center_loop
jump_scroll_center_loop_end:

		PUSH	d2/a1
		bsr	reset_line_address_buf_2
		tst	d1
		bmi	@f			表示行分だけデータがある(末尾ではない)
		bsr	end_of_buffer_sub
@@:
		POP	d2/a1
		moveq	#-1,d1
		lea	(line_buf,pc),a3
@@:
		addq	#1,d1			;見つけた行の表示は何行目か？
		cmpa.l	(a3)+,a1		;(バッファ末尾を表示した時以外は 0)
		bne	@b

		st	d0			;再描画 必要
		bra	@f
jump_scroll_same_page:
		move	(window_line,pc),d1
		sub	d0,d1
		sf	d0			;再描画 不要
@@:		
		lea	(cursorX,pc),a0
		move	d3,(a0)+		;cursorX
		move	d2,(a0)+		;cursorXbyte
		move	d1,(a0)			;cursorY
		tst.b	d0
		beq	@f
		bsr	draw_backscroll
@@:		moveq	#0,d0
		rts

get_isearch_start:
		lea	(search_char_adr,pc),a2
		move.l	(a2),a1			;search_char_adr
		clr.l	(a2)+
		move	(a2)+,d3		;search_x
		move	(a2)+,d2		;search_xbyte

		moveq	#0,d1
		lea	(-1,a1),a2
		suba	d2,a2
		TopChk	a2
		move.b	(a2),d1

		move.l	a1,d0			;tst.l a1
		rts

search_sub_getcur:
		bsr	get_cursor_line_buffer
		bmi	search_sub_getcur_end

		move	(cursorXbyte,pc),d2
		moveq	#0,d1
		move.b	(a1)+,d1		;バイト数
		adda	d2,a1
		EndChk2	a1

		tst	d2			;not minus
search_sub_getcur_end:
search_backward_end:
		rts

* C-\
key_search_backward_current_word:
		bsr	readline_yank_current_word
		bra	key_search_backward
* ↑検索／次検索
key_search_backward:
		lea	(search_backward_mes,pc),a1
		bsr	input_string
		beq	search_backward_end
		bsr	copy_search_str
key_search_backward_next:
		bsr	make_search_work
		beq	search_backward_end
		lea	(searching_mes,pc),a1
		bsr	print_message
		bsr	search_backward_main
		bra	search_found_or_not

* ↑検索メイン処理
* in	d7.l	最初の1バイト(2バイト文字の場合は上位バイトのみ)
*	a0.l	case_table
*	a3.l	line_buf
*	a5.l	(a5):		検索文字列
*		(GETSMAX+1,a5):	漢字検査テーブル
* out	d0.l	0:検索成功 -1:失敗
* 備考:
*	i_search_backward_mainでは
*	成功すればsearch_char_adr、search_x、search_xbyteがセットされる.
*	失敗すればsearch_char_adrがクリアされる.

i_search_backward_main:
		bsr	get_isearch_start
		bne	@f
search_backward_main:
		bsr	search_sub_getcur
		bmi	search_not_found
@@:
		.ifdef	__EMACS
		bclr	#ISEARCH_bit,(bitflag-case_table,a0)
		beq	@f

		addq.l	#1,a1			;後で1～2を引くので上限検査は不要
		addq	#1,d2
@@:
		.endif
		moveq	#0,d3
search_backward_not_match:
		subq.b	#1,d2
		bpl	search_backward_cmp

		subq.l	#2,a1			;行の先頭まで遡った場合
		TopChk	a1
		move.b	(a1),d1
		move.b	d1,d2			前の行の右端から
		bne	search_backward_not_match
search_not_found:
		moveq	#-1,d0
		rts
search_backward_cmp:
		subq.l	#1,a1
		TopChk	a1

		move.b	(a1),d3
		cmp.b	(a0,d3.w),d7
		bne	search_backward_not_match
		bsr	search_sub
		bne	search_backward_not_match

		bsr	search_zenkaku_check	一致文字列が全角の途中からか調べる
		bcs	search_backward_not_match

		lea	(search_char_adr,pc),a2
		move.l	a1,(a2)+		;search_char_adr
		move	d1,(a2)+		;search_x
		move	d2,(a2)+		;search_xbyte
		bra	search_found_scroll

search_zenkaku_check:
usereg		.reg	d1-d2/a1
		PUSH	usereg
		suba	d2,a1
		TopChk	a1
		move	d2,d1
		moveq	#0,d2
		moveq	#0,d3
		bra	@f
zenkaku_check_loop:
		bsr	get_char
@@:		cmp	d2,d1
		bhi	zenkaku_check_loop
		POP	usereg
		rts

* 検索サブ(2文字目以降を比較する)
search_sub:
usereg		.reg	d1-d4/a1-a2/a5
		PUSH	usereg
		lea	(ctype_table,pc),a2
		moveq	#0,d0
search_sub_loop:
		move	d3,d4			前の比較文字
		move.b	(a5)+,d3
		beq	search_sub_found
		addq.l	#1,a1
		EndChk	a1
		addq	#1,d2
		cmp	d1,d2
		bne	search_sub_cmpchar

		tst.b	(a1)+
		beq	search_sub_not_found
		EndChk	a1
		moveq	#0,d2
		moveq	#0,d1
		move.b	(a1)+,d1
		beq	search_sub_not_found
		EndChk	a1
search_sub_cmpchar:
		move.b	(a1),d0
		BRA_IF_MB (a2,d4.w),@f
		move.b	(a0,d0.w),d0		;大文字化(-x オプション指定時)
@@:		cmp.b	d0,d3
		beq	search_sub_loop
search_sub_not_found:
		moveq	#-1,d0
search_sub_found:
		POP	usereg
		rts

* 終了 ---------------------------------------- *

* OPT.1 + UNDO : 画面を残したまま終了
key_suspend_condrv:
		lea	(bitflag,pc),a0
		tst.b	(a0)			HELPMODE_bit
		bmi	key_kill_condrv		ヘルプモードなら抜けるだけ
		bset	#SUSPEND_bit,(a0)
key_kill_condrv:
		addq.l	#4,sp
		rts

* カーソル行のバッファアドレスを求める -------- *
* out	a1.l	アドレス
*	a3.l	line_buf
*	ccr N	0:OK 1:error

get_cursor_line_buffer:
		movea.l	d0,a1
		lea	(line_buf,pc),a3
		move	(cursorY,pc),d0
		lsl	#2,d0
		move.l	(a3,d0.w),d0
		exg	d0,a1
		rts

* カット＆ペースト ---------------------------- *

		.ifdef	__EMACS			;+07b
key_yank_region:
		move.l	(mark_char_adr,pc),d0
		bne	@f
no_mark_error:
		bsr	visual_bell		;マークがないならエラー
		lea	(no_mark_err_mes,pc),a1
		bra	print_message
@@:
		.else
key_yank:
		move.l	(mark_char_adr,pc),d0	;マークされていなければ
		beq	key_yank_current_word	;カーソル位置の単語をペースト
		.endif

		bsr	get_mark_area
		beq	key_kill_condrv

		bsr	kill_region_start
yank_and_kill_condrv:
		addq.l	#4,sp
yank_sub:
		lea	(bitflag,pc),a0
		bset	#AFTERCR_bit,(a0)	改行直後フラグを立ててペースト位置を先頭にする
		move.l	(pastebuf_adr,pc),(paste_pointer-bitflag,a0)
		rts

key_yank_current_word:
		bsr	get_cursor_line_buffer
		bmi	key_kill_condrv

		movem.l	(pastebuf_size,pc),d2/a2
*		movea.l	(pastebuf_adr,pc),a2
		bsr	yank_current_word_sub
		bra	yank_and_kill_condrv

yank_current_word_sub:
		moveq	#0,d3
		move.b	(a1)+,d3
		move	(cursorXbyte,pc),d1
		adda	d1,a1
		EndChk2	a1
		bra	@f
yank_current_word_loop:
		cmp	d1,d3
		beq	yank_current_word_endofline
yank_current_word_nextline:
		move.b	(a1)+,d0
		cmpi.b	#$20,d0
		bls	yank_current_word_end
		EndChk	a1
		move.b	d0,(a2)+
		addq	#1,d1
@@:
		subq.l	#1,d2
		bne	yank_current_word_loop
yank_current_word_end:
		bra	set_nulstr_yankptr

yank_current_word_endofline:
		tst.b	(a1)+
		beq	yank_current_word_end
		EndChk	a1
		move.b	(a1)+,d3
		beq	yank_current_word_end
		EndChk	a1
		moveq	#0,d1
		bra	yank_current_word_nextline

* リージョンのアドレスを得る ------------------ *
* out	d0.w/d1.w	前端・後端の桁位置(バイト単位)
*	d2.w/d3.w	〃	    行バイト数
*	a0.l/a1.l	〃	    文字アドレス
* ccrZ	0:OK 1:範囲が無効

get_mark_area:
		move.l	(mark_char_adr,pc),d1
		beq	get_mark_area_end

		movea.l	(mark_line_adr,pc),a0
		moveq	#0,d0
		moveq	#0,d2
		move.b	(a0)+,d2		d2.w=マーク行の桁数
		bra	@f
1:
		addq	#1,d0			d0.w=markXbyte
		addq.l	#1,a0			a0.l=マーク位置
@@:
		EndChk	a0
		cmpa.l	d1,a0
		bne	1b

		bsr	get_cursor_line_buffer
		bpl	@f

		moveq	#0,d0
		bra	get_mark_area_end
@@:
		moveq	#0,d3
		move.b	(a1)+,d3		d3.w=カーソル位置の桁

		move	(cursorXbyte,pc),d1
		adda	d1,a1			a1.l=カーソル位置
		EndChk2	a1
		cmpa.l	a0,a1
		bcc	@f
		exg	d0,d1			a0.l:開始<a1.l:終了にする
		exg	d2,d3
		exg	a0,a1
@@:
		cmpa.l	(buffer_old,a6),a0
		bcc	@f
		cmpa.l	(buffer_old,a6),a1
		bcs	@f
		exg	d0,d1			a1.l<=old<a0.lなら交換
		exg	d2,d3
		exg	a0,a1
@@:
		cmpa.l	a0,a1			;equalならcursor==mark
get_mark_area_end:
kill_region_end:
		rts

		.ifdef	__EMACS
key_kill_region:
		bsr	get_mark_area
		beq	no_mark_error
		addq.l	#4,sp			;カットバッファに転送して終了
		bra	kill_region_start
key_copy_region:
		bsr	get_mark_area
		beq	no_mark_error
		bra	kill_region_start

		.else
key_kill_region:
		addq.l	#4,sp
key_copy_region:
		bsr	get_mark_area
		beq	kill_region_end		;マーク範囲は無効
		bra	kill_region_start
		.endif

kill_region_start:
		movem.l	(pastebuf_size,pc),d1/a2
*		movea.l	(pastebuf_adr,pc),a2
		subq.l	#1,d1
kill_region_loop:
		cmp	d0,d2
		bne	@f
		moveq	#0,d0			次の行
		addq.l	#1,a0
		EndChk	a0
		move.b	(a0)+,d2
		EndChk	a0
@@:
		cmpa.l	a0,a1
		beq	@f
		move.b	(a0)+,(a2)+
		EndChk	a0
		addq	#1,d0
		subq.l	#1,d1
		bne	kill_region_loop
@@:
		bra	set_nulstr_yankptr

*  U : カーソル～文頭ペースト
key_yank_from_beginning_of_line:
		pea	(yank_and_kill_condrv,pc)
		bra	kill_from_beginning_of_line_sub

* ^U : カーソル～文頭カット
key_kill_from_beginning_of_line:
		pea	(key_kill_condrv,pc)
		bra	kill_from_beginning_of_line_sub

kill_from_beginning_of_line_sub:
		bsr	get_cursor_line_buffer
		bmi	kill_cancel

		movea.l	a1,a0			;行頭
		adda	(cursorXbyte,pc),a1
		addq.l	#1,a1			;ポインタ
		EndChk2	a1
		moveq	#0,d2
		bra	1f
@@:
		suba	d2,a0
1:
		subq.l	#1,a0
		TopChk	a0
		move.b	(a0),d2			前の行のバイト数
		subq.l	#1,a0
		beq	@f
		TopChk	a0
		cmpi.b	#CR,(a0)
		bne	@b			前の行が改行で終わるまで繰り返す
@@:
		addq.l	#2,a0
		EndChk2	a0
		move.b	(a0)+,d2
		EndChk	a0
		moveq	#0,d0
		bra	kill_region_start
kill_cancel:
		addq.l	#8,sp
		rts

*  K : カーソル～文末ペースト
key_yank_to_end_of_line:
		pea	(yank_and_kill_condrv,pc)
		bra	kill_to_end_of_line_sub

* ^K : カーソル～文末カット
key_kill_to_end_of_line:
		pea	(key_kill_condrv,pc)
		bra	kill_to_end_of_line_sub

kill_to_end_of_line_sub:
		bsr	get_cursor_line_buffer
		bmi	kill_cancel

		moveq	#0,d3
		move.b	(a1)+,d3
		move	(cursorXbyte,pc),d1
		adda	d1,a1
		EndChk2	a1
		movem.l	(pastebuf_size,pc),d2/a2
*		movea.l	(pastebuf_adr,pc),a2
		subq.l	#1,d2
kill_to_end_of_line_loop:
		cmp	d1,d3
		bne	@f

		tst.b	(a1)+			カーソルが右端にあった場合
		beq	set_nulstr_yankptr
		EndChk	a1
		move.b	(a1)+,d3
		beq	set_nulstr_yankptr
		EndChk	a1
		moveq	#0,d1
@@:
		move.b	(a1)+,d0
		cmpi.b	#CR,d0
		beq	set_nulstr_yankptr
		EndChk	a1
		move.b	d0,(a2)+
		addq	#1,d1
		subq.l	#1,d2
		bne	kill_to_end_of_line_loop
set_nulstr_yankptr:
		movea.l	(pastebuf_adr,pc),a1
		bsr	cut_tail_mb_high
		clr.b	(a2)
		lea	(paste_pointer,pc),a1
		move.l	a2,(a1)
		rts

* a1.l からの文字列の末尾の半端なコードを削る.
* (-1,a2) がマルチバイト文字の 1 バイト目なら a2.l -= 1.
* in	a1.l	文字列の先頭アドレス
*	a2.l	文字列の末尾アドレス
* out	a2.l	〃
* break	d0/a0

cut_tail_mb_high:
		cmpa.l	a1,a2
		beq	cut_tail_mb_high_skip
		lea	(a2),a0
cut_tail_mb_high_loop:
		move.b	-(a0),d0
		bpl	cut_tail_mb_high_end	;ASCII
		cmpi.b	#$a0,d0
		bcs	@f			;multi-byte
		cmpi.b	#$e0,d0
		bcs	cut_tail_mb_high_end	;kana
@@:
		cmpa.l	a1,a2
		bne	cut_tail_mb_high_loop
		addq.l	#1,a0
cut_tail_mb_high_end:
		suba.l	a2,a0
		move	a0,-(sp)
		lsr	(sp)+
		bcs	cut_tail_mb_high_skip
		subq.l	#1,a2
cut_tail_mb_high_skip:
		rts


* ↑カット＆ペースト / ↓カーソル移動 --------- *

* A : 一語左に移動
backward_word_loop:
		move	(cursorY,pc),d0
		lsl	#2,d0
		movea.l	(a3,d0.w),a1
		subq.l	#2,a1
		TopChk	a1
		cmpi.b	#CR,(a1)
		beq	backward_word_end
key_backward_word:
		bsr	key_backward_char
		tst.l	d0
		ble	backward_word_end
		cmpi	#CR,d0
		beq	backward_word_end

		move	(cursorXbyte,pc),d1
		beq	backward_word_loop	;左端まで進んだ
		cmpi	#$20,d0
		bls	key_backward_word
		move	(cursorY,pc),d0
		lsl	#2,d0
		movea.l	(a3,d0.w),a1
		adda	d1,a1
		EndChk2	a1
		cmpi.b	#$20,(a1)
		bhi	key_backward_word
backward_word_end:
forward_word_end:
		rts

* F : 一語右に移動
key_forward_word:
		bsr	get_cursor_line_buffer
		bmi	forward_word_end

		move	(cursorXbyte,pc),d1
		adda	d1,a1
		addq.l	#1,a1
		EndChk2	a1
		cmpi.b	#CR,(a1)
		beq	key_forward_char
forward_word_loop:
		tst.b	(a1)
		beq	forward_word_end
		cmpi.b	#SPACE,(a1)
		sls	d4
		bsr	key_forward_char

		move	(cursorY,pc),d0
		lsl	#2,d0
		movea.l	(a3,d0.w),a1
		moveq	#0,d2
		move.b	(a1)+,d2		;カーソル行のバイト数

		move	(cursorXbyte,pc),d1
		adda	d1,a1
		EndChk2	a1
		cmpi.b	#CR,(a1)
		beq	forward_word_end
		tst.b	d4
		beq	@f
		cmpi.b	#SPACE,(a1)		制御記号(or空白)が続く間は
		bhi	forward_word_end	一単語と見なす
@@:
		tst.b	(a1)
		bpl	@f
		cmpi.b	#$a0,(a1)
		bcs	forward_word_mb		$80-$9f
		cmpi.b	#$e0,(a1)
		bcs	@f			$e0-$ff
forward_word_mb:
		addq	#1,d1
@@:
		addq	#1,d1
		cmp	d1,d2
		bne	forward_word_loop
		movea.l	(a3,d0.w),a1		カーソルが右端にあった場合
		addq.l	#1,a1
		adda	d1,a1
		EndChk2	a1
		tst.b	(a1)+
		beq	key_forward_char
		EndChk	a1
		tst.b	(a1)+
		bne	key_forward_word
forward_char_end:
		rts

* → , その他 : カーソルを一桁右に移動する
key_forward_char:
		lea	(cursorX,pc),a0
		.ifndef	__EMACS
			move.l	(a0),d6		;cursorX/Xbyte
		.endif
		move	(a0)+,d3		;cursorX
		move	(a0)+,d2		;cursorXbyte
		move	(a0),d7			;cursorY

		bsr	get_cursor_line_buffer
		bmi	forward_char_end
		moveq	#0,d1
		move.b	(a1)+,d1
		beq	forward_char_end

		adda	d2,a1
		EndChk2	a1
		bsr	get_char
		cmp	d1,d2
		beq	cursor_to_right_tip
cursor_to_right_move:
		subq.l	#cursorY-cursorX,a0
		move	d3,(a0)+
		move	d2,(a0)
		.ifndef	__EMACS
* カーソル移動に伴うマーク反転領域の変更を追従させる
redraw_cursor_char:
		bsr	draw_char_c
		move.l	(cursorX,pc),d6		cursorX/Xbyte
		move	(cursorY,pc),d7
		bra	draw_char_c
		.endif
cursor_to_right_endofbuf:
		rts

cursor_to_right_tip:
		tst.b	(a1)+
		beq	cursor_to_right_move
		EndChk	a1

		subq.l	#cursorY-cursorX,a0
		clr.l	(a0)+

		move	(window_line,pc),d0
		cmp	(a0),d0			;cursorY
		beq	@f
		addq	#1,(a0)			;カーソル位置の変更のみ
		.ifdef	__EMACS
			rts
		.else
			bra	redraw_cursor_char
		.endif
@@:
		.ifdef	__EMACS
			btst	#OPT_S_bit,(option_flag,pc)
			beq	centering_a1	;EMACS 形式の半頁スクロール
		.endif
		bsr	scroll_up_sub		;ED 形式の一行スクロール
		subq	#1,d7
		move	(window_line,pc),d0
		.ifdef	__EMACS
			bra	draw_line_d0
		.else
			bsr	draw_line_d0
			bra	redraw_cursor_char
		.endif

		.ifdef	__EMACS
centering_a1_prev:
			subq.l	#1,a1
			suba	d0,a1
			TopChk	a1
centering_a1:
			moveq	#0,d3		;a1 = 新しいカーソル行
			moveq	#0,d2
			st	(line_buf)	;カーソル行を中央に表示する
			bra	jump_scroll
						;X=0,Xbyte=0 のままでよい
		.endif

* Z , ^Z , ~→ : 一行スクロールアップ
key_move_window_down:
		lea	(line_buf,pc),a3
		tst.l	(a3)
		bmi	move_window_down_end

		move	(window_line,pc),d0
		lsl	#2,d0
		movea.l	(a3,d0.w),a1
		moveq	#0,d1
		move.b	(a1)+,d1
		adda	d1,a1
		EndChk2	a1
		tst.b	(a1)+
		beq	move_window_down_end
		EndChk	a1

		bsr	scroll_up_sub
		lea	(cursorY,pc),a4
		tst	(a4)
		beq	@f

		subq	#1,(a4)			cursorY
		bra	move_window_down_cursor_fixed
@@:
		bsr	check_column_pop_curx
		.ifndef	__EMACS
			moveq	#0,d0
			bsr	draw_line_d0
		.endif
move_window_down_cursor_fixed:
		move	(window_line,pc),d0
		bra	draw_line_d0
move_window_down_end:
		rts

* X , ^X , ↓ : カーソル下移動
key_next_line:
		lea	(line_buf,pc),a3
		lea	(cursorY,pc),a2
		move	(a2),d0
		cmp	(window_line,pc),d0
		beq	next_line_scroll

		addq	#1,d0
		lsl	#2,d0
		tst	(a3,d0.w)
		bmi	next_line_end
		addq	#1,(a2)			;cursorY
		.ifdef	__EMACS
			bra	check_column_pop_curx
		.else
			bsr	check_column_pop_curx
			move	(a2),d0		;cursorY
			bra	next_line_no_scroll
		.endif
next_line_scroll:
		lsl	#2,d0
		movea.l	(a3,d0.w),a1
		moveq	#0,d1
		move.b	(a1)+,d1
		adda	d1,a1
		EndChk2	a1
		tst.b	(a1)+
		beq	next_line_end
		EndChk	a1
		.ifdef	__EMACS
			btst	#OPT_S_bit,(option_flag,pc)
			bne	@f
			bsr	centering_a1	;EMACS 形式の半頁スクロール
			bra	check_column_pop_curx
@@:
		.endif
		bsr	scroll_up_sub		;ED 形式の一行スクロール
		bsr	check_column_pop_curx
		move	(window_line,pc),d0
		.ifndef	__EMACS
next_line_no_scroll:
			bsr	draw_line_d0
			subq	#1,d0
		.endif
		bra	draw_line_d0
next_line_end:
move_window_up_end:
		rts

* W , ^W , ~← : 一行スクロールダウン
key_move_window_up:
		lea	(line_buf,pc),a3
		movea.l	(a3),a1
		move.l	a1,d0
		bmi	move_window_up_end	;バッファが空

		subq.l	#1,a1
		TopChk	a1
		moveq	#0,d0
		move.b	(a1),d0
		beq	move_window_up_end
		bsr	scroll_down_sub
		move	(window_line,pc),d0
		lea	(cursorY,pc),a4
		cmp	(a4),d0
		beq	@f

		addq	#1,(a4)
		bra	move_window_up_cursor_fixed
@@:
		bsr	check_column_pop_curx
		.ifndef	__EMACS
			move	(a4),d0		cursorY
			bsr	draw_line_d0
		.endif
move_window_up_cursor_fixed:
		moveq	#0,d0
		bra	draw_line_d0

* E , ^E , ↑ : カーソル上移動
key_previous_line:
		lea	(line_buf,pc),a3
		lea	(cursorY,pc),a0
		subq	#1,(a0)
		.ifdef	__EMACS
			bpl	check_column_pop_curx
		.else
			bpl	previous_line_no_scroll
		.endif
		clr	(a0)
		movea.l	(a3),a1
		move.l	a1,d0
		bmi	previous_line_end	;バッファは空

		subq.l	#1,a1
		TopChk	a1
		moveq	#0,d0
		move.b	(a1),d0
		beq	previous_line_end

		.ifdef	__EMACS
			btst	#OPT_S_bit,(option_flag,pc)
			bne	@f
			bsr	centering_a1_prev	;EMACS 形式の半頁スクロール
			bra	check_column_pop_curx
@@:
		.endif
		bsr	scroll_down_sub		;ED 形式の一行スクロール
		bsr	check_column_pop_curx
		moveq	#0,d0
		.ifndef	__EMACS
			bra	@f
previous_line_no_scroll:
			bsr	check_column_pop_curx
			move	(a0),d0
@@:
			bsr	draw_line_d0
			addq	#1,d0
		.endif
		bra	draw_line_d0
previous_line_end:
		rts

* 表示画面の左上にいた場合はスクロールしてから書き足す
backward_char_prev_line:
		addq	#1,(a4)			;cursorY

		subq.l	#1,a1
		TopChk	a1
		moveq	#0,d0
		move.b	(a1),d0
		beq	backward_char_end

		.ifdef	__EMACS
			btst	#OPT_S_bit,(option_flag,pc)
			bne	@f
			bsr	centering_a1_prev	;EMACS 形式の半頁スクロール
			bra	check_column_max
@@:
		.endif
		bsr	scroll_down_sub		;ED 形式の一行スクロール
		addq	#1,(a4)			;cursorY
		moveq	#0,d0
		bsr	draw_line_d0
		bra	key_backward_char

* S , ^S , ← : カーソル左移動
key_backward_char:
		.ifdef	__EMACS
			lea	(cursorY,pc),a4
		.else
			lea	(cursorX,pc),a4
			move.l	(a4)+,d6	;cursorX/Xbyte
			move	(a4),d7		;cursorY
		.endif
		moveq	#0,d2
		moveq	#0,d3
		bsr	get_cursor_line_buffer
		bmi	backward_char_end

		move	(cursorXbyte,pc),d1
		bne	@f

		subq	#1,(a4)			;cursorY
		bmi	backward_char_prev_line

		bsr	get_cursor_line_buffer
		moveq	#0,d1
		move.b	(a1),d1
@@:
		addq.l	#1,a1
		EndChk	a1
@@:
		move	d3,d4
		swap	d4
		move	d2,d4
		bsr	get_char
		cmp	d2,d1
		bne	@b
		move.l	d4,-(a4)		;cursorX/Xbyte
		.ifdef	__EMACS
			rts
		.else
			bra	redraw_cursor_char
		.endif
backward_char_end:
		moveq	#-1,d0
		rts


* ^A : 行の左端に移動
key_beginning_of_line:
			lea	(cursorX,pc),a0
			clr.l	(a0)+		;cursorX/Xbyte
		.ifdef	__EMACS
			rts
		.else
			lea	(line_buf,pc),a3
			move	(a0),d0		;cursorY
			bra	draw_line_d0
		.endif

* ROLL_DOWN , ^R : スクロールダウン
key_scroll_down:
		lea	(line_buf,pc),a3
		movea.l	(a3),a0
		move	(window_line,pc),d1
		move	d1,d0
		addq	#1,d0
		lsl	#2,d0
		adda	d0,a3			;a3=&line_buf[最後+1]

		moveq	#-1,d2
		bsr	scroll_down_p_sub
		addq	#1,d2
		beq	key_beginning_of_page	;元から先頭行にいた場合は左上に移動する
		bsr	check_column_pop_curx
		bra	draw_backscroll

* ROLL_UP , ^C : スクロールアップ
key_scroll_up:
		lea	(line_buf,pc),a3
		move	(window_line,pc),d1
		move	d1,d0
		lsl	#2,d0
		move.l	(a3,d0.w),d0
		bmi	key_end_of_buffer	;1頁分下に行けない

		movea.l	d0,a0			;a0=最終行のアドレス
		move	d1,d2
scroll_up_loop:
		moveq	#0,d0
		move.b	(a0)+,d0
		adda	d0,a0
		EndChk2	a0

		tst.b	(a0)+
		beq	@f			;今の行がバッファ最終行
		EndChk	a0

		tst.b	(a0)
@@:		beq	key_end_of_buffer	;改行直後なら最後の行は入れない

		move	d1,d0
		movea.l	a3,a1
		lea	(4,a1),a2
		subq	#1,d0
@@:
		move.l	(a2)+,(a1)+
		dbra	d0,@b
		move.l	a0,(a1)
		dbra	d2,scroll_up_loop
		bsr	check_column_pop_curx
		bra	draw_backscroll

* M-< , C-rolldown : set-mark + beginning-of-buffer
		.ifdef	__EMACS
key_beginning_of_buffer_mark:
			bsr	key_set_mark_quiet
		.endif
* T , F0 : バッファの先頭行に移動
key_beginning_of_buffer:
		bsr	beginning_of_buffer_sub
* ^T : カーソルを現在表示中の画面の左上に移動
key_beginning_of_page:
		lea	(cursorX,pc),a0
		clr.l	(a0)+			cursorX/Xbyte
		clr	(a0)			cursorY
		bra	draw_backscroll

* M-> , C-rollup : set-mark + end-of-buffer
		.ifdef	__EMACS
key_end_of_buffer_mark:
		bsr	key_set_mark_quiet
		bra	key_end_of_buffer
		.endif

* B , F1 : バッファの最終行に移動
key_end_of_buffer:
		bsr	end_of_buffer_sub
jump_to_page_end:
		lea	(cursorY,pc),a0
		move	d2,(a0)
		bpl	@f
		clr	(a0)
@@:
		bsr	check_column_max	;前の桁位置に関係なく右端に移動
		bra	draw_backscroll

* ^B : カーソルを現在表示中の画面の右下に移動
key_end_of_page:
		lea	(line_buf,pc),a3
		movea.l	a3,a0
		moveq	#-1,d2
@@:
		tst.l	(a0)+
		bmi	@f			バッファ末尾
		addq	#1,d2
		cmp	(window_line,pc),d2
		bne	@b
@@:
		bra	jump_to_page_end

* ^F : 行の右端に移動
key_end_of_line:
		bsr	get_cursor_line_buffer
		bmi	end_of_line_end
		.ifdef	__EMACS
			bra	check_column_max
		.else
			bsr	check_column_max
			move	(cursorY,pc),d0
			bra	draw_line_d0
		.endif
end_of_line_end:
already_help:
		rts

* ^J , ^] , HELP : ヘルプ表示
key_help:
		lea	(bitflag,pc),a0
		tas	(a0)			HELPMODE_bit
		bmi	already_help

		move.l	(line_buf,pc),-(sp)
		lea	(buffer_size,pc),a0
		move.l	(a0),-(sp)		ヘルプメッセージの容量
		move.l	#help_mes_end-help_mes_top,(a0)+
		move.l	(a0),-(sp)		;mark_char_adr
		clr.l	(a0)+
		move.l	(a0),-(sp)		;mark_line_adr
		clr.l	(a0)+
		move.l	(a0),-(sp)		cursorX/byte
		clr.l	(a0)+
		move.l	(a0),-(sp)		cursorY/curx_save
		clr.l	(a0)

		move.l	a6,-(sp)
		lea	(help_buf_struct,pc),a6
		bsr	key_beginning_of_buffer

		.ifndef	__EMACS
			move.b	(ins_clr_flag,pc),-(sp)
			bsr	clr_ins_led
		.endif

		bsr	keyinp_loop_start	;メインループを再帰呼び出し
		lea	(cursorY,pc),a0

		.ifndef	__EMACS
			bsr	restore_ins_led
			move.b	(sp)+,(ins_clr_flag-cursorY,a0)
		.endif

		movea.l	(sp)+,a6
		bclr	#HELPMODE_bit,(bitflag-cursorY,a0)
		move.l	(sp)+,(a0)		;cursorY/curx_save
		move.l	(sp)+,-(a0)		;cursorX/byte
		move.l	(sp)+,-(a0)		;mark_line_adr
		move.l	(sp)+,-(a0)		;mark_char_adr
		move.l	(sp)+,-(a0)		buffer_size

		movea.l	(sp)+,a0
		bsr	reset_line_address_buf_2
		bsr	draw_backscroll
		bra	initialize_keypaste_buffer
**		rts


* 追加機能 ------------------------------------ *

* V : タグジャンプ

.ifdef	__TAG_JMP
key_tag_jump:
		bsr	get_cursor_line_buffer
		bmi	tag_jump_end
		moveq	#SPACE,d2
		moveq	#TAB,d3
		moveq	#0,d1
		move.b	(a1)+,d1
@@:
		subq.b	#1,d1			;空白を見つける
		bcs	tag_jump_end
		EndChk	a1
		move.b	(a1)+,d0
		cmp.b	d3,d0
		beq	@f
		cmp.b	d2,d0
		bne	@b
@@:
		subq.b	#1,d1			;空白を飛ばす
		bcs	tag_jump_end
		EndChk	a1
		move.b	(a1)+,d0
		cmp.b	d3,d0
		beq	@b
		cmp.b	d2,d0
		beq	@b

		moveq	#'0',d2
		moveq	#'9',d3
		cmp.b	d2,d0
		bcs	tag_jump_end		;数字ではない
		cmp.b	d3,d0
		bhi	tag_jump_end		;〃
		lea	(general_work,pc),a0
		move	#(CTRL+'X')<<8+(CTRL+'G'),(a0)+
@@:
		move.b	d0,(a0)+		;数字をバッファに書き込む
		subq.b	#1,d1
		bcs	@f
		EndChk	a1
		move.b	(a1)+,d0
		cmp.b	d2,d0
		bcs	@f
		cmp.b	d3,d0
		bls	@b
@@:
		move.b	#CR,(a0)+
		clr.b	(a0)

		lea	(general_work,pc),a0
		bclr	#AFTERCR_bit,(bitflag-general_work,a0)	;ペーストヘッダ抑制
		move.l	a0,(paste_pointer-general_work,a0)
		addq.l	#4,sp

		bra	key_next_line		;カーソルを次の行に進める
tag_jump_end:
		rts
.endif


* C-x = : バッファ位置表示
* "line:$00000000 char:$00000000 column:$00/$00 code:$0000"

		.ifdef	__BUF_POS
key_buffer_position:
		lea	(general_work,pc),a1
		lea	(buf_pos_line,pc),a0
		bsr	str_copy
		move.l	a1,d0
		bsr	get_cursor_line_buffer
		bmi	buffer_position_end	;本当に必要か?
		exg	d0,a1
		movea.l	d0,a2			;d0 = a2 = line
		bsr	to_hex

**		lea	(buf_pos_char,pc),a0
		bsr	str_copy
		addq.l	#1,a2
		adda	(cursorXbyte,pc),a2
		EndChk2	a2			;a2 = char
		move.l	a2,d0
		bsr	to_hex

**		lea	(buf_pos_col1,pc),a0
		bsr	str_copy
		lea	(cursorX,pc),a3
		moveq	#0,d0
		move	(a3),d0
		bsr	to_hex

**		lea	(buf_pos_col2,pc),a0
		bsr	str_copy
		move.l	(a3),-(sp)		;X/Xbyte 保存
		PUSH	a0-a3			;end-of-line と同じ処理をして
		bsr	check_column_max	;最大桁位置を求める
		POP	a0-a3
		moveq	#0,d0
		move	(a3),d0
		move.l	(sp)+,(a3)		;X/Xbyte 復帰
		bsr	to_hex

**		lea	(buf_pos_code,pc),a0
		bsr	str_copy
		exg	a1,a2			;a1 = char
		bsr	get_char		;d0 = code
		lea	(a2),a1
		bsr	to_hex

		lea	(general_work,pc),a1
		bra	print_message
buffer_position_end:
		rts

buf_pos_line:	.dc.b	'line:$',0
buf_pos_char:	.dc.b	' char:$',0
buf_pos_col1:	.dc.b	' column:$',0
buf_pos_col2:	.dc.b	'/$',0
buf_pos_code:	.dc.b	' code:$',0
		.even

* 数値を 16 進数文字列に変換する.
* in	d0.l	数値
*	a1.l	文字列を書き込むバッファ
* out	a1.l	NUL のアドレス
* break	d0.l
* 仕様:	文字列の末尾には NUL が書き込まれる.
*	上位の 0 は省略される.

usereg:		.reg	d1
to_hex:
		move.l	usereg,-(sp)
		clr	-(sp)			;番兵(NUL を兼ねる)
to_hex_loop:
		moveq	#$f,d1			;下位桁から取り出す
		and	d0,d1
		addi	#'0',d1
		cmpi	#'9',d1
		bls	@f
		.ifdef	__UPPER
		addq	#'A'-('9'+1),d1
		.else
		addi	#'a'-('9'+1),d1
		.endif
@@:
		move.b	d1,-(sp)		;スタック上に溜める
		lsr.l	#4,d0
		bne	to_hex_loop
* d0.l = $1a0 の場合
* sp:	.dc	'1'<<8, 'a'<<8, '0'<<8, 0
to_hex_loop2:
		move.b	(sp)+,(a1)+		;上位桁からバッファに転送する
		bne	to_hex_loop2
		subq.l	#1,a1
		move.l	(sp)+,usereg
		rts

		.endif	/* __BUF_POS */

* C-l : 画面再描画

		.ifdef	__EMACS
key_redraw_window:
		bsr	draw_window
		bsr	get_cursor_line_buffer
		st	(a3)			;カーソル行を中央に表示する
		move	(cursorX,pc),d3
		move	(cursorXbyte,pc),d2
		bra	jump_scroll
**		rts
		.endif


* C-bs : バッファリング中止・再開

key_toggle_buffering_mode:
		bsr	toggle_buffering_mode
		bra	display_system_status

toggle_buffering_mode:
		PUSH	d0-d1/a0
		lea	(condrv_put_char,pc),a0
		eori	#RTS.xor.MOVEM,(a0)

		cmpi.b	#1,(MPUTYPE)
		bls	@f

		moveq	#3,d1
		IOCS	_SYS_STAT
@@:
		POP	d0-d1/a0
insert_file_cancel:
		rts

* C-clr : バッファ初期化

key_clear_buffer:
		lea	(mark_char_adr,pc),a0
		clr.l	(a0)+			;mark_char_adr
		clr.l	(a0)+			;mark_line_adr

		bsr	initialize_backscroll_buffer
		bra	key_beginning_of_buffer

* ^Y : ファイル読み込み
key_insert_file:
		move.b	(bitflag,pc),d0
		bmi	insert_file_cancel	HELP表示中は使用不可

		lea	(insert_file_prompt,pc),a1
		bsr	input_string
		beq	insert_file_cancel
		bsr	unfold_home
		bsr	check_diskready
		bmi	disk_notready_error

		clr	-(sp)
		move.l	a1,-(sp)
		DOS	_OPEN
		addq.l	#6,sp
		move.l	d0,d4
		bmi	fileopen_error

		moveq	#6,d1
		bsr	is_file_io_enable
		bne	fileread_disable

		lea	(io_buffer,pc),a5
		lea	(REQHEAD_SIZE,a5),a0
		move.l	a0,(DEVIO_ADDRESS,a5)
insert_file_loop:
		pea	(IOBUFSIZE)
		move.l	a0,-(sp)
		move	d4,-(sp)
		DOS	_READ
		lea	(10,sp),sp
		move.l	d0,(DEVIO_LENGTH,a5)
		ble	insert_file_end
		bsr	xcon_output
		bra	insert_file_loop
insert_file_end:
		bsr	close_filehandle_d4
		bsr	clear_mark		* _and_redraw
		bra	key_end_of_buffer

close_filehandle_d4:
		move	d4,-(sp)
		DOS	_CLOSE
		addq.l	#2,sp
		rts

* 入出力可能なら d0.b=0
is_file_io_enable:
		move	d4,-(sp)
		clr	-(sp)
		DOS	_IOCTRL
		asr.b	#8,d0
		bpl	@f

		move	d1,(sp)
		DOS	_IOCTRL
		not.b	d0
@@:
		addq.l	#4,sp
		rts

* in	a1.l	ファイル名
*	d0.l	0:OK -1:Error
check_diskready:
		lea	(GETSMAX+1,a1),a0
		move.l	a0,-(sp)
		move.l	a1,-(sp)
		DOS	_NAMECK
		addq.l	#8,sp
		tst.l	d0			「ワイルドカード指定なし」だけOK
		bne	nocheck_diskready	他はオープン時にエラーがおきる
		moveq	#0,d1
@@:		move.b	(a0),d1
		subi.b	#'A'-1,d1		DRVCTRLするドライブ

		clr.b	(2,a0)
		move.l	a0,-(sp)
		move.l	a0,-(sp)
		clr	-(sp)
		DOS	_ASSIGN
		lea	(10,sp),sp
		cmpi	#$50,d0
		beq	@b			仮想ドライブの親をたどる

		move	d1,-(sp)		MD=0
		DOS	_DRVCTRL
		addq.l	#2,sp
		tst.l	d0
		bmi	disk_notready
		lsr	#1,d0
		bcs	disk_notready		メディア誤挿入
		lsr	#1,d0
		bcc	disk_notready		挿入されていない
nocheck_diskready:
		moveq	#0,d0
		rts
disk_notready:
		moveq	#-1,d0
		rts

filewrite_disable:
		move	#'出',d0
		bra	@f
fileread_disable:
		move	#'入',d0
@@:
		lea	(file_io_disable_mes,pc),a1
		move	d0,(a1)
		bsr	close_filehandle_d4
		bra	1f

fileopen_error:
		lea	(fopen_err_mes_tbl,pc),a1
		move.b	d0,(fopen_err_mes-fopen_err_mes_tbl,a1)
check_open_err:
		cmp.b	(a1)+,d0
		beq	1f
@@:		tst.b	(a1)+
		bne	@b
		bra	check_open_err

disk_notready_error:
		lea	(disk_notready_mes,pc),a1
1:
		bra	print_message

* ファイル名先頭の ~/ 及び ~\ を $HOME に展開する.
* in	a1.l	ファイル名
* break	d0

unfold_home:
		movem.l	a0-a2,-(sp)
		lea	(a1),a0
		cmpi.b	#'~',(a0)+
		bne	unfold_home_skip
		cmpi.b	#'/',(a0)		;~/
		beq	@f
		cmpi.b	#'\',(a0)		;~\
		bne	unfold_home_skip
@@:
		lea	(-(256+256),sp),sp
		pea	(sp)			;環境変数 HOME の値を収得
		clr.l	-(sp)
		pea	(env_home,pc)
		DOS	_GETENV
		addq.l	#12-4,sp
		move.l	d0,(sp)+
		bne	unfold_home_skip2

		lea	(sp),a2
		STRCAT	a0,a2			;'/'以降を連結する
		lea	(sp),a0
		lea	(a1),a2
		STRCPY	a0,a2			;元のバッファに転送
unfold_home_skip2:
		lea	(256+256,sp),sp
unfold_home_skip:
		movem.l	(sp)+,a0-a2
		rts


		.ifndef	__EMACS
* L : ラベル定義(カーソル位置は左端)
key_set_label:
		lea	(define_label_mes,pc),a0
		moveq	#0,d0
		bsr	print_label_mes
		bsr	get_key_a_z
		bhi	define_label_end

		lsl	#2,d0
		lea	(label_buffer,pc),a0
		adda	d0,a0			格納先

		move	(cursorY,pc),d0
		lsl	#2,d0
		lea	(line_buf,pc),a1
		adda	d0,a1			保存元

		move.l	(a1),(a0)+
define_label_end:
jump_label_end:
		rts

* Shift + 7 (') : 指定ラベルまで移動
key_jump_label:
		lea	(jump_label_mes,pc),a0
		moveq	#-1,d0
		bsr	print_label_mes
		bsr	get_key_a_z
		bhi	jump_label_end

		lsl	#2,d0
		lea	(label_buffer,pc),a0
		adda	d0,a0
		move.l	(a0),d1
		beq	jump_label_end		未定義のラベル
		movea.l	d1,a0			Jump先

		movea.l	(buffer_now,a6),a1
		bra	@f
jump_label_loop
		subq.l	#1,a1
		TopChk	a1
		move.b	(a1),d0
		beq	jump_label_end		バッファの先頭まで行った
		subq.l	#1,a1
		suba	d0,a1
		TopChk	a1
@@:
		cmpa.l	a0,a1
		bne	jump_label_loop

		moveq	#0,d2
		moveq	#0,d3
		bra	jump_scroll

print_label_mes:
		lea	(general_work,pc),a1
		bsr	str_copy

		moveq	#'A',d1
		lea	(label_buffer,pc),a0
label_print_loop:
		tst.l	(a0)+
		sne	-(sp)
		cmp.b	(sp)+,d0
		bne	@f

		move.b	d1,(a1)+
@@:
		addq.b	#1,d1
		cmpi.b	#'Z',d1
		bls	label_print_loop

		lea	(label_mes_end,pc),a0
		bsr	str_copy
		lea	(general_work,pc),a1
		bra	print_message

get_key_a_z:
		bsr	get_key_sub
		andi	#$df,d0
		subi	#'A',d0
		cmpi	#'Z'-'A',d0
		rts

		.endif

str_copy:
		move.b	(a0)+,(a1)+
		bne	str_copy
		subq.l	#1,a1
		rts

get_key_sub:
		suba.l	a1,a1
get_key_sub_loop:
		IOCS	_ONTIME
		cmp.l	a1,d0
		bcs	@f

		bsr	blink_cursor_direct
		IOCS	_ONTIME
		lea	(BLINKCYCLE),a1
		adda.l	d0,a1
@@:
		bsr	call_orig_b_keysns
		tst.l	d0
		beq	get_key_sub_loop

		bsr	call_orig_b_keyinp
		tst.b	d0
		beq	get_key_sub_loop

		bra	clear_message		プロンプトを消す

* Q : 設定変更
key_toggle_buffer_mode:
		lea	(toggle_buffer_mode_mes,pc),a1
		bsr	print_message
		bsr	get_key_sub
		ori.b	#$20,d0

		.irpc	%a,trbeicx
		cmpi.b	#'&%a',d0
		beq	toggle_buffer_mode_%a
		.endm
		rts

* 表示状態が変わるフラグ
key_toggle_tab_disp:
toggle_buffer_mode_t:
		lea	(option_t_flag,pc),a0	Tab表示
		bra	@f
key_toggle_cr_disp:
toggle_buffer_mode_r:
		lea	(option_r_flag,pc),a0	R:改行表示
		bra	@f
@@:
		not.b	(a0)
		bra	draw_backscroll

* 表示には関係ないフラグ

* B(-nb:BS処理)
toggle_buffer_mode_b:
toggle_option_nb:

PUT_BS_TBL:	.reg	(putbuf_ctrl_table+BS*2)
PUT_BS:		.equ	(putbuf_bs-putbuf_ctrl_table)
PUT_BS_NB:	.equ	(putbuf_bs_nb-putbuf_ctrl_table)

		lea	(PUT_BS_TBL,pc),a0
		eori	#PUT_BS.xor.PUT_BS_NB,(a0)

		not.b	(option_nb_flag-PUT_BS_TBL,a0)
		rts

* E(-ne:ESC削除)
toggle_buffer_mode_e:
toggle_option_ne:

PUT_ESC_TBL:	.reg	(putbuf_ctrl_table+ESC*2)
PUT_ESC:	.equ	(putbuf_esc-putbuf_ctrl_table)
PUT_ESC_NE:	.equ	(putbuf_esc_ne-putbuf_ctrl_table)

		lea	(PUT_ESC_TBL,pc),a0
		eori	#PUT_ESC.xor.PUT_ESC_NE,(a0)

		not.b	(option_ne_flag-PUT_ESC_TBL,a0)
		rts

* I(-nt:TAB変換)
toggle_buffer_mode_i:
toggle_option_nt:

PUT_TAB_TBL:	.reg	(putbuf_ctrl_table+TAB*2)
PUT_TAB:	.equ	(putbuf_tab-putbuf_ctrl_table)
PUT_TAB_NT:	.equ	(putbuf_tab_nt-putbuf_ctrl_table)

		lea	(PUT_TAB_TBL,pc),a0
		eori	#PUT_TAB.xor.PUT_TAB_NT,(a0)

		not.b	(option_nt_flag-PUT_TAB_TBL,a0)
		rts

* C(-nc:制御記号削除)
toggle_buffer_mode_c:
toggle_option_nc:

PUT_CTRL:	.equ	(putbuf_ctrl-putbuf_ctrl_table)
PUT_CTRL_NC:	.equ	(putbuf_ctrl_nc-putbuf_ctrl_table)

		move.l	#PUT_CTRL_LIST,d0
		lea	(putbuf_ctrl_table,pc),a0
toggle_option_nc_loop:
		lsr.l	#1,d0
		bcc	@f
		eori	#PUT_CTRL.xor.PUT_CTRL_NC,(a0)
@@:		addq.l	#2,a0

		tst.l	d0
		bne	toggle_option_nc_loop

		lea	(option_nc_flag,pc),a0
		not.b	(a0)
		rts

toggle_buffer_mode_x:
		lea	(case_table+'a',pc),a0	X:検索時の大文字小文字の区別ON/OFF切り換え
		not.b	(option_x_flag-(case_table+'a'),a0)

		moveq	#'z'-'a',d0
1:		eori.b	#$20,(a0)+
		dbra	d0,1b
		rts

* Shift + Q : 設定変更その２(-m?)
key_toggle_text_mode:
		lea	(toggle_text_mode_mes,pc),a1
		bsr	print_message
		bsr	get_key_sub
		lea	(option_m_flag,pc),a0
		subi.b	#'1',d0
		cmpi.b	#'4'-'1',d0
		bhi	toggle_text_mode_end
		beq	toggle_text_mode_4
		cmpi.b	#'3'-'1',d0
		beq	toggle_text_mode_3

		bchg	d0,(a0)			;1:マウス制御 2:テキスト保存
toggle_text_mode_end:
		rts

toggle_text_mode_4:
		bchg	d0,(a0)			;4:カーソル制御抑制
		lea	(iocs_curflg,pc),a0
		bne	@f
		move	(a0),(CSRSWITCH)	;制御する -> 制御しない
		rts
@@:		move	(CSRSWITCH),(a0)	;制御しない -> 制御する
		IOCS	_OS_CUROF
		rts

toggle_text_mode_3:
		bchg	d0,(a0)			;3:テキスト使用状況無視
		bne	toggle_text_mode_end
		bra	gm_tgusemd_orig_tm1

gm_tgusemd_orig_tm1:
		moveq	#1,d2
gm_tgusemd_orig:
		move.l	#_GM_INTERNAL_MODE<<16+1,d1
		IOCS	_TGUSEMD
		rts

* 一行スクロールしてワーク更新＆描画 ---------- *

* in	d0.w	新しい最上段行のバイト数
*	a1.l	〃		末尾のバイト数格納位置
*	a3.l	line_buf

scroll_down_sub:
		movea.l	a3,a0
		move	(window_line,pc),d2
		move	d2,d1
		addq	#1,d1
		lsl	#2,d1
		adda	d1,a0
		lea	(-4,a0),a2
		move	d2,d1
		subq	#1,d1
@@:
		move.l	-(a2),-(a0)
		dbra	d1,@b
		suba	d0,a1
		subq.l	#1,a1
		TopChk	a1
		move.l	a1,(a2)

		move	d2,d0
		lsl	#2,d0			d0も意味があるので注意
		move.b	d0,d1
		subq	#1,d1
		lsl	#8,d1
		move.b	d0,d1
		addq.b	#4-1,d1
		add	(text_ras_no,pc),d1
		bra	rascpy_down

scroll_up_sub:
		movea.l	a3,a0
		move	(window_line,pc),d0
		subq	#1,d0
		lea	(4,a0),a2
@@:
		move.l	(a2)+,(a0)+
		dbra	d0,@b
		move.l	a1,(a0)
		bra	rascpy_up_all


* カーソル位置の補正 -------------------------- *

* 保存しておいた桁位置まで右に移動する.
check_column_pop_curx:
		lea	(cursorX,pc),a4
		move	(curx_save,pc),(a4)
		bra	check_column

* 現在の行の右端まで移動する.
check_column_max:
		lea	(cursorX,pc),a4
		st	(a4)
		bra	check_column

* 今までと同じカーソル桁位置まで右に移動する.
check_column:
		lea	(cursorX,pc),a4
		moveq	#0,d4
		bsr	get_cursor_line_buffer
		bmi	check_column_end

		moveq	#0,d3
		moveq	#0,d2
		moveq	#0,d1
		move.b	(a1)+,d1
		EndChk	a1
check_column_loop:
		cmp	d1,d2
		beq	check_column_end2

		move	d3,d4
		swap	d4
		move	d2,d4
		bsr	get_char
		cmp	(a4),d3			;cursorX
		bls	check_column_loop
check_column_end:
		move.l	d4,(a4)
		rts

check_column_end2:
		tst.b	(a1)
		bne	check_column_end
		move	d3,d4
		swap	d4
		move	d2,d4
		bra	check_column_end

* 一文字収得する ------------------------------ *
*	d0.w	文字
*	d2.w	行頭からのバイト数
*	d3.w	行頭からの桁数(2バイト半角文字は1として換算される)
*	a1.l	バッファポインタ

get_char:
		moveq	#0,d0
		move.b	(a1)+,d0
		beq	get_char_endofbuf
		addq	#1,d2
		EndChk	a1
		tst.b	d0
		bpl	get_char_1byte		;ASCII
		cmpi.b	#$a0,d0
		bcs	get_char_2byte		;MS-Kanji
		cmpi.b	#$e0,d0
		bcs	get_char_1byte		;1byte Kana
get_char_2byte:
		lsl	#8,d0
		addq	#1,d2
		move.b	(a1)+,d0

* 二バイト文字の上位バイトだけがバッファ末尾に入っていた場合
* の暴走対策. 通常は有り得ないが、一応念の為.
		bne	@f
		lsr	#8,d0
		subq	#1,d2
		bra	get_char_1byte
@@:
		EndChk	a1
get_char_1byte:
		cmpi	#TAB,d0
		bne	@f
		ori	#7,d3
@@:
		addq	#1,d3
		cmpi	#$8140,d0
		bcs	@f
		cmpi	#$8540,d0
		bcs	get_char_wide		8140～853fまで全角
		cmpi	#$869f,d0
		bcs	@f
		cmpi	#$f000,d0
		bcc	@f
get_char_wide:
		addq	#1,d3			869f～efffまで全角
@@:		rts

get_char_endofbuf:
		subq.l	#1,a1
		rts

* ラスタコピー呼び出し ------------------------ *
* break d0-d2

rascpy_up_all:
		move	(window_line,pc),d0
		move	#$0400,d1
rascpy_up_shl2:
		lsl	#2,d0
rascpy_up:
		add	(text_ras_no,pc),d1	ラスタ番号
		move	d0,d2
		moveq	#%1100,d0
		bra	@f
rascpy_down:
		move	d0,d2
		move	#$ff<<8+%1100,d0
@@:
		move.l	d3,-(sp)
		move	d0,d3
		IOCS	_TXRASCPY
		move.l	(sp)+,d3
		rts

* バックスクロール画面の最下行を消して行入力をする
* in	a1.l	プロンプトとして表示する文字列
* out	a1.l	入力バッファの先頭+2(入力された文字列)
*	ccrZ	入力文字数が 0 なら ccrZ=1
input_string:
usereg:		.reg	d1-d7/a2-a5
		PUSH	usereg

		lea	(stop_level,pc),a5
		move	(a5),-(sp)		;push stop_level
		st	(a5)

		move.l	(TXADR),-(sp)		;IOCSwork待避
		move.l	(TXSTOFST),-(sp)
		move.l	(CSRXMAX),-(sp)		;& CSRYMAX
		move.l	(CSRX),-(sp)		;& CSRY
		move.b	(FIRSTBYTE),-(sp)
		move.b	(TXCOLOR),(1,sp)
		move.b	(LEDSTAT),-(sp)

;テキストを待避
		move	(window_line,pc),d0
		add	(down_line,pc),d0
		addq	#2,d0
		move	d0,-(sp)		;!
		mulu	#(128*16),d0

		lea	(TEXT_VRAM),a2
		move.l	a2,(TXADR)		;T-VRAMアドレス(プレーンの指定)
		move.l	d0,(TXSTOFST)		;表示アドレスオフセット
		adda.l	d0,a2
		lea	(line_store_buf+128*16*2,pc),a3
		bsr	move_textblock		;plane0待避
		adda.l	#$20000-128*16,a2
		bsr	move_textblock		;     1
*		move.l	a2,-(sp)
*		move.l	a3,-(sp)

;該当行をクリア
		move.l	#(WIDTH-1).shl.16+0,(CSRXMAX)
		clr.b	(FIRSTBYTE)
		moveq	#2,d1
		IOCS	_B_CLR_ST		画面全体を消去
		move.b	#2,(TXCOLOR)		青で表示
		IOCS	_B_PRINT		prompt
		addq.b	#1,(TXCOLOR)		白

		move	(sp)+,d1		;!
		lsl	#2,d1
		moveq	#0,d0			;マスクは描き直さない
		moveq	#4-1,d2
		bsr	clear_text_raster

		bsr	fep_enable

		btst	#3,(option_m_flag,pc)
		bne	@f
		IOCS	_OS_CURON
@@:
		lea	(general_work,pc),a1
		move	#GETSMAX.shl.8,(a1)
		move.l	a1,-(sp)
		DOS	_GETSS
		addq.l	#4,sp

		btst	#3,(option_m_flag,pc)
		bne	@f
		IOCS	_OS_CUROF
@@:
		bsr	fep_disable
		bsr	clear_message		;マウスプレーンの復帰

* 待避したテキストを元に戻す
*		movea.l	(sp)+,a2
*		movea.l	(sp)+,a3
		exg	a2,a3
		bsr	move_textblock		プレーン1 を復帰
		suba.l	#$20000-128*16,a3
		bsr	move_textblock		〃	0

		move.b	(sp)+,(LEDSTAT)
		IOCS	_LEDSET
		move.b	(1,sp),(TXCOLOR)	IOCSwork復帰
		move.b	(sp)+,(FIRSTBYTE)
		move.l	(sp)+,(CSRX)
		move.l	(sp)+,(CSRXMAX)
		move.l	(sp)+,(TXSTOFST)
		move.l	(sp)+,(TXADR)

		move	(sp)+,(a5)		;pop stop_level

		lea	(general_work+1,pc),a1
		tst.b	(a1)+			入力文字数
		POP	usereg
		rts

move_textblock:
		moveq	#(128*16)/(4*8)-1,d0
@@:
		movem.l	(a2)+,d1-d7/a4
		movem.l	d1-d7/a4,-(a3)
		dbra	d0,@b
		rts


* バックログ画面最下行の文字列を消去する ------ *

clear_message:
usereg:		.reg	d0-d3/a1
		PUSH	usereg

		move.b	(down_line+1,pc),-(sp)
		move	(sp),d1
		move.b	(sp)+,d1
		add.b	(window_line+1,pc),d1
		addq	#2,d1
		lsl	#2,d1
		moveq	#1,d2
		moveq	#%1100,d3
		IOCS	_TXRASCPY

		move.b	d1,-(sp)
		move	(sp),d1
		move.b	(sp)+,d1
		addq.b	#1,d1			;それをすぐ下にコピー
		moveq	#3,d2
		IOCS	_TXRASCPY

		lea	(mes_end_adr,pc),a1
		clr.l	(a1)
		POP	usereg
		rts

; in	d1.w	機能番号(d1.hw=-1)
; out	d0.hw	返値
gm_tgusemd:
		addi.l	#(_GM_INTERNAL_MODE+1).shl.16,d1
		IOCS	_TGUSEMD
		subi	#_GM_INTERNAL_MODE,d0
		rts

* FEP がオープン出来るようにする
fep_enable:
		lea	(fepctrl_mode,pc),a4
		clr.l	(a4)
		pea	(2)			かな漢字変換モードの収得
		DOS	_KNJCTRL
		btst	#FEPOPEN_bit,(bitflag,pc)
		beq	@f
		move.l	d0,(a4)			以前のかな漢字変換モード
@@:
*		pea	(8)			かな漢字変換モード固定状態の収得
		addq.l	#8-2,(sp)
		DOS	_KNJCTRL
		move.l	d0,-(a4)		fepctrl_lock
*		pea	(1)			固定解除
		subq.l	#8-1,(sp)
		pea	(7)
		DOS	_KNJCTRL
		addq.l	#8,sp
		rts

* FEP の状態を元に戻す
fep_disable:
		lea	(fepctrl_lock,pc),a4
		move.l	(a4)+,-(sp)
		pea	(7)
		DOS	_KNJCTRL		ロックモードを元に戻す
		btst	#FEPOPEN_bit,(bitflag,pc)
		beq	@f
		move.l	(a4),(4,sp)		fepctrl_mode
		subq.l	#7-1,(sp)
		DOS	_KNJCTRL		変換モードを元に戻す
@@:
		addq.l	#8,sp
		rts

* 最下行メッセージ表示/消去 ----------- *

* 以前の表示の最後から追加で文字列を表示する
print_message_cont:
usereg		.reg	d0-d2/a0-a2
		PUSH	usereg
		movea.l	(mes_end_adr,pc),a0
		bra	print_m_loop

* バックログ画面最下行に文字列を表示する
* in	a1.l = 表示する文字列
print_message:
		PUSH	usereg
		movea.l	(text_address,pc),a0
		move	(window_line,pc),d0
		swap	d0
		clr	d0
		lsr.l	#5,d0		*128*16
		adda.l	d0,a0		↓半角スペースを表示したことにする
		lea	(128*(16+8)+1,a0),a0
print_m_loop:
		move	a0,d0
		cmpi.b	#WIDTH,d0	画面右端までいったら、それ以上表示しない
		bcc	print_message_end

		moveq	#0,d1
		move.b	(a1)+,d1
		beq	print_message_end
		lea	(ctype_table,pc),a2
		BRA_IF_SB (a2,d1.w),@f

		lsl	#8,d1
		move.b	(a1)+,d1
		beq	print_message_end
@@:
		moveq	#8,d2
		IOCS	_FNTADR
		movea.l	d0,a2
		tst	d1
		bne	draw_multibyte
@@:
		move.b	(a2)+,(a0)
		lea	(128,a0),a0
		dbra	d2,@b
		lea	(-128*16+1,a0),a0
		bra	print_m_loop
print_message_end:
		lea	(mes_end_adr,pc),a1
		move.l	a0,(a1)
		POP	usereg
		rts

draw_multibyte:
		move.b	(a2)+,(a0)+
		move.b	(a2)+,(a0)
		lea	(128-1,a0),a0
		dbra	d2,draw_multibyte
		lea	(-128*16+2,a0),a0
		bra	print_m_loop

* CONDRV.SYS System Call ---------------------- *

condrv_system_call:
usereg		.reg	d1-d7/a0-a6
		PUSH	usereg
		lea	(syscall_table,pc),a0
@@:
		move	(a0)+,d2		address
		beq	syscall_error1
		cmp	(a0)+,d0		code
		bne	@b
		adda	d2,a0
		jsr	(a0)
syscall_return:
		POP	usereg
		rts
syscall_error1:
		moveq	#-1,d0
		bra	syscall_return

SYSTBL:		.macro	%callno
		.dc	syscall_%callno-($+4),$%callno
		.endm

syscall_table:
		SYSTBL	0000
		SYSTBL	0010
		SYSTBL	0020
		SYSTBL	0021
		SYSTBL	0022
		SYSTBL	0023
		SYSTBL	0024
		SYSTBL	ffff
		.dc	0

syscall_0000:
		move	#RTS,d0
		tst	d1
		beq	@f
		move	#MOVEM,d0
@@:
		lea	(condrv_put_char,pc),a1
		cmp	(a1),d0
		beq	@f

		bsr	toggle_buffering_mode
syscall_0010:
@@:		moveq	#0,d0
		rts

syscall_0020:
		lea	(key_init_orig,pc),a0
		move.l	(a0),d0			元の処理アドレス
		move.l	a1,(a0)			新しい処理アドレスを設定
		rts

syscall_0021:
		lea	(key_init_orig,pc),a0
		cmpa.l	(a0),a1			現在の処理アドレスを正しく知っているか？
		bne	syscall_error2
		move.l	a2,(a0)			以前のアドレスに戻す
		moveq	#0,d0
		rts

syscall_0022:
		move.l	(key_init_orig,pc),d0
		rts

syscall_0023:
		lea	(bufmod_stack,pc),a0
		move.l	(a0)+,d0
		move.b	(a0),d3			bufmod_height
		tst	d1
		bne	syscall_0023_push

		subq.b	#1,d3
		bmi	syscall_0023_pop
syscall_error2:
		moveq	#-2,d0
		rts
syscall_0023_pop:
		move.b	d3,(a0)

		btst	d3,d0
		sne	d1
		ext	d1
		bra	syscall_0000
syscall_0023_push:
		cmpi.b	#31,d3
		beq	syscall_error2		スタックが満杯なのに PUSH しようとした
		bset	d3,d0
		lea	(condrv_put_char,pc),a1
		cmpi	#RTS,(a1)
		bne	@f
		bchg	d3,d0
@@:
		addq.b	#1,d3
		move.b	d3,(a0)
		move.l	d0,-(a0)
		moveq	#0,d0
		rts

syscall_0024:
		lea	(stop_level,pc),a0
		tst	d1
		beq	syscall_0024_get
		bmi	syscall_0024_minus
*syscall_0024_plus:
		cmpi	#$ffff,(a0)
		beq	syscall_0024_error
		addq	#1,(a0)
		bra	syscall_0024_set_char
syscall_0024_minus:
		tst	(a0)
		beq	syscall_0024_error
		subq	#1,(a0)
syscall_0024_set_char:
		btst	#OPT_G_bit,(option_flag,pc)
		beq	syscall_0024_get
		move	(a0),d0			;stop_level 表示用の文字を作成
		beq	@f
		addi	#'0',d0
		cmpi	#'9',d0
		bls	@f
		moveq	#'9',d0
@@:
		move.b	d0,(stop_level_char-stop_level,a0)
		bsr	display_system_status
syscall_0024_get:
		moveq	#0,d0
		move	(a0),d0
		rts
syscall_0024_error:
		moveq	#-1,d0
		rts

syscall_ffff:
		move.l	#VERSION_ID,d0
		rts

; デバイス初期化ルーチン ---------------------- *

general_work:
xcon_init:
usereg		.reg	d1-d7/a0-a3/a6
		PUSH	usereg

* condrv.sysを二重登録していないか調べる
		clr	-(sp)
		pea	(xcon_filename,pc)
		DOS	_OPEN
		addq.l	#6,sp
		move.l	d0,d1
		bmi	double_check_ok

		move	d1,-(sp)
		clr	-(sp)
		DOS	_IOCTRL
		addq.l	#4,sp
		tst	d0
		lea	(double_include_err_mes,pc),a2
		bmi	print_error_and_return
double_check_ok:
		lea	(option_flag,pc),a6

*各種テーブルの初期化
		lea	(case_table+256,pc),a0
		move	#256-1,d0
@@:		move.b	d0,-(a0)
		dbra	d0,@b

		lea	(end_,pc),a3
		move.l	a3,(DEVIO_ENDADR,a5)
		movea.l	(DEVIO_ARGUMENT,a5),a2
		bsr	option_check
		bsr	initialize_keypaste_buffer

		lea	(hook_table_top,pc),a0	各種ベクタフック
		move.l	(buffer_size,pc),d0
		bne	hook_loop_start		OK

		lea	(no_buf_err_mes,pc),a2	* -b が指定されなかった場合は常駐しない
		move.b	(no_mem_flag,pc),d0
		beq	print_error_and_return
		lea	(no_mem_err_mes,pc),a2	* メモリが足りない場合
print_error_and_return:
		bsr	print_title
		lea	(a2),a1
		jsr	(a3)
		move	#$700d,d0		エラーの場合はこの値を返すらしい
		bra	devini_exit

hook_loop:
		movea	d0,a1
		move.l	(a0),d0
		move.l	(a1),(a0)+		現在の処理アドレスを保存
		lea	(top_,pc),a2
		adda	d0,a2
		move.l	a2,(a1)			新しい処理アドレスを設定
hook_loop_start:
		move	(a0),d0
		bne	hook_loop

* 改行せずにリセットで再起動した場合でも、タイトルの前に一行空くようにする.
		movea.l	(backscroll_buf_adr,pc),a0
		movea.l	(buffer_now+4,a0),a0
		tst.b	(a0)
		beq	@f

		moveq	#LF,d1
		bsr	condrv_put_char_force
@@:
		bsr	print_title

		lea	(initmes1,pc),a1	バックスクロールバッファ～
		jsr	(a3)
		move.l	($1c00),d1		バッファ先頭アドレス
		bsr	print_hexadecimal

		move	#'-',-(sp)
		DOS	_PUTCHAR

		moveq	#32,d1
		add.l	(buffer_size,pc),d1
		bsr	print_kiro_decimal

		lea	(initmes2,pc),a1
		btst	#BUFINIT_bit,(bitflag,pc)
		beq	@f
		lea	(initmes3,pc),a1	バッファを初期化した場合
@@:		jsr	(a3)

		lea	(initmes4,pc),a1	キーボードバッファ～
		jsr	(a3)
		move.l	(pastebuf_adr,pc),d1
		bsr	print_hexadecimal

*		move	#'-',(sp)
		DOS	_PUTCHAR

		move.l	(pastebuf_size,pc),d1
		bsr	print_kiro_decimal

		lea	(initmes5,pc),a1	～確保しました
		jsr	(a3)

		move.l	#$e_ffff,-(sp)		! 表示
		DOS	_CONCTRL
		addq.l	#4+2,sp

		move.b	(option_o_flag,pc),d1
		subq.b	#3,d1			OPT.2
		bne	@f
		IOCS	$0b			OPT.2 はテレビコントロールにしない
@@:
		moveq	#0,d0
devini_exit:
		POP	usereg
		rts

print_title:
		lea	(title_mes,pc),a1
		lea	(@f,pc),a3
@@:
		move.l	a1,-(sp)
		DOS	_PRINT
		addq.l	#4,sp
@@:
		rts

option_end:
		movea.l	(sp)+,a2
option_check:
		tst.b	(a2)+
		bne	option_check		自分のファイル名or今見た引数
		move.b	(a2)+,d0
		beq	@b			0,0 で終わり
		move.l	a2,-(sp)
		cmpi.b	#'-',d0
		bne	option_end
next_option:
		move.b	(a2)+,d0
		beq	option_end
		ori.b	#$20,d0
		lea	(option_tbl,pc),a0
@@:
		move.l	(a0)+,d1
		beq	option_end		未定義のオプション
		cmp.b	d0,d1
		bne	@b
		swap	d1
		adda	d1,a0
		jmp	(a0)
*引数を持たないオプションは続けて書くことができるように、分岐後は
*正常な引数			bra	next_option
*異常〃(次の引数まで無視)	bra	option_end

option_tbl:
		.irpc	%a,abcfghjkmnoprstvwx
		.dc	(option_%a-$-4),'&%a'
		.endm
		.dc.l	0

option_p:
		lea	(option_p_flag,pc),a0
		bra	@f
option_r:
		lea	(option_r_flag,pc),a0
		bra	@f
option_t:
		lea	(option_t_flag,pc),a0
		bra	@f
@@:
		not.b	(a0)
		bra	next_option

option_x:
		bsr	toggle_buffer_mode_x
		bra	next_option

option_m:
		lea	(option_m_flag,pc),a0
		bsr	get_value
		bmi	@b			数値省略時は反転
		move.b	d1,(a0)
		bra	next_option

option_n:
		move.b	(a2)+,d0
		beq	option_end
		ori.b	#$20,d0
		lea	(option_n_list,pc),a0

		cmp.b	(a0)+,d0		;-nb:BS 処理
		bne	@f
		bsr	toggle_option_nb
		bra	option_n
@@:
		cmp.b	(a0)+,d0		;-nc:制御記号削除
		bne	@f
		bsr	toggle_option_nc
		bra	option_n
@@:
		cmp.b	(a0)+,d0		;-ne:ESC削除
		bne	@f
		bsr	toggle_option_ne
		bra	option_n
@@:
		cmp.b	(a0)+,d0		;-nt:TAB->SPACE
		bne	@f
		bsr	toggle_option_nt
@@:
		bra	option_n

option_a:
		lea	(ras_int_adr,pc),a0
		bra	@f
option_v:
		lea	(vdisp_int_adr,pc),a0
@@:
		lea	(dummy_rte,pc),a1
		move.l	a1,(a0)
		bra	next_option

option_h:
		lea	(default_paste_header,pc),a0
		move.b	(a2)+,d0
		beq	@f			省略した場合は最初から>が設定されている
		move.b	d0,(a0)
@@:
		move.b	(a0),(paste_header-option_flag,a6)
		bra	option_end

option_o:
		moveq	#$20,d0
		or.b	(a2)+,d0		;nul検査は不要...

		lea	(option_o_list,pc),a0
		moveq	#3,d1
@@:
		cmp.b	(a0)+,d0
		dbeq	d1,@b
		bne	@f

		move.b	d1,(option_o_flag-option_flag,a6)
@@:		bra	option_end

option_c:
		bsr	toggle_buffering_mode
		bra	next_option

option_f:
		moveq	#OPT_F_bit,d2
		bsr	get_value
		bmi	option_flag_chg		-f
		tst	d1
		beq	option_flag_chg		-f0

		move.b	d1,(option_f_col-option_flag,a6)	表示色指定
		bra	@f

option_g:
		moveq	#OPT_G_bit,d2
		bra	option_flag_chg
option_j:
		moveq	#OPT_J_bit,d2
		bra	option_flag_chg
option_s:
		moveq	#OPT_S_bit,d2
		bra	option_flag_chg
option_flag_chg:
		bchg	d2,(a6)
@@:		bra	next_option

option_b:
		cmpi.b	#'#',(a2)
		sne	d2			d2.b==0で初期化する
		bne	@f
		addq.l	#1,a2
@@:
		bsr	get_value
		bmi	@f			;無指定
		move.l	(buffer_size,pc),d0
@@:
		bne	next_option		;指定済み

		mulu	#1024,d1		KB単位
		movea.l	($1c00),a0		メインメモリ末尾
		suba.l	d1,a0
		bcs	@f
		lea	(a0),a1
		suba.l	(DEVIO_ENDADR,a5),a1
		bcs	@f
		cmpa.l	#$80000,a1
@@:
		scs	(no_mem_flag-option_flag,a6)
		bcs	@f			512KB 残らないなら無視
		moveq	#32,d0			管理情報の分バッファ正味は少なくなる
		sub.l	d0,d1
		bmi	@f			-b0 の場合

		move.l	d1,(buffer_size-option_flag,a6)
		move.l	a0,($1c00)		メモリを削る
		move.l	a0,(backscroll_buf_adr-option_flag,a6)

		SFTbtst	SFT_SHIFT
		bne	buffer_clear_start
		tst.b	d2			-b#n
		beq	buffer_clear_start
		cmpi.l	#'hmk*',(a0)+
		beq	@f			破壊されていないなら初期化しない
buffer_clear_start:
		bsr	initialize_backscroll_buffer
		bset	#BUFINIT_bit,(bitflag-option_flag,a6)
@@:
		move.l	(buffer_now,a0),(line_buf-option_flag,a6)
		bra	next_option

option_k:
		bsr	get_value
		bmi	@f
		cmpa.l	(DEVIO_ENDADR,a5),a3
		bne	@f			変更済み
		subq	#1,d1
		bls	@f			1以下

		mulu	#1024,d1
		movea.l	($1c00),a0
		suba.l	d1,a0
		suba.l	a3,a0			a3 = デバイスドライバの末尾
		cmpa.l	#$80000,a0
		bcs	@f
		add.l	d1,(pastebuf_size-option_flag,a6)
		add.l	d1,(DEVIO_ENDADR,a5)
@@:
		bra	next_option

option_w:
		bsr	get_value		開始位置
		bmi	option_w_end

		move	d1,d2
		moveq	#0,d1
		cmpi.b	#',',(a2)
		bne	@f

		addq.l	#1,a2
		bsr	get_value		行数
		bmi	option_w_end
@@:
		cmpi	#4,d2
		bcs	option_w_end		4 以下は無視
		move	d2,d0
		cmpi	#28,d0
		bcc	option_w_end		28 以上は無視

		move	d2,(window_line-option_flag,a6)
		bra	@f
option_w_loop:
		move	(down_line,pc),d0
		add	(window_line,pc),d0
		cmpi	#28,d0
		bcc	option_w_end		一番下まで行った場合

		lea	(text_address,pc),a0
		addi.l	#$800,(a0)+
		addi	#$404,(a0)+
		addq	#1,(a0)
@@:
		dbra	d1,option_w_loop
option_w_end:
		bra	next_option

print_hexadecimal:
		lea	(str_buf,pc),a1
print_hex_loop:
		moveq	#$f,d0
		and	d1,d0
		addi	#'0',d0
		cmpi	#'9',d0
		bls	@f
		.ifdef	__UPPER
		addq	#'A'-('9'+1),d0
		.else
		addi	#'a'-('9'+1),d0
		.endif
@@:
		move.b	d0,-(a1)
		lsr.l	#4,d1
		bne	print_hex_loop
		jmp	(a3)			print

print_kiro_decimal:
		lea	(str_buf,pc),a1
		moveq	#10,d0
		lsr.l	d0,d1			KB単位にする
@@:
		divu	d0,d1
		swap	d1
		addi	#'0',d1
		move.b	d1,-(a1)
		clr	d1
		swap	d1
		bne	@b
		jmp	(a3)			print

* 数値収得
get_value:
		bsr	is_number
		move	d0,d1
		bpl	@f
*		moveq	#-1,d0
		rts
get_value_loop:
		mulu	#10,d1
		add	d0,d1
@@:
		bsr	is_number
		bpl	get_value_loop
		moveq	#0,d0
		rts

is_number:
		move.b	(a2)+,d0
		subi.b	#'0',d0
		cmpi.b	#9,d0
		bhi	@f

		ext	d0
		rts
@@:
		subq.l	#1,a2
		moveq	#-1,d0
		rts

command_exec:
		DOS	_EXIT

* Data Section -------------------------------- *

		.data				xcon_initからを作業領域に使用する為、
		.even				なるべく上の方に破壊されてもいいものを置く
title_mes:
		.dc.b	CR,LF
		.dc.b	'Console driver version ',VERSION,KEYBIND_TYPE
		.dc.b	' / Copyright 1990 卑弥呼☆, ',DATE,' ',AUTHOR,'.',CR,LF
str_buf:	.dc.b	0
xcon_filename:	.dc.b	'XCON',0

double_include_err_mes:
		.dc.b	'ドライバは既に登録されています.',CR,LF,0
no_buf_err_mes:
		.dc.b	'バックスクロールバッファの容量が指定されていません.',CR,LF,0
no_mem_err_mes:
		.dc.b	'メモリが足りません.',CR,LF,0

initmes1:	.dc.b	'バックスクロールバッファ($',0
initmes2:	.dc.b	'KB)は初期化しません.',CR,LF,0
initmes3:	.dc.b	'KB)を初期化しました.',CR,LF,0
initmes4:	.dc.b	'キーボードバッファ($',0
initmes5:	.dc.b	'KB)を確保しました.',CR,LF,0

option_o_list:	.dc.b	'21cs'
option_n_list:	.dc.b	'bcet'

* ここより上側は破壊可能な文字列 -------------- *

condrv_pal:	.dc.b	'CONDRV.PAL',0
env_home:	.dc.b	'HOME',0

search_forward_mes:
		.dc.b	' 前方向検索文字列:',0
search_backward_mes:
		.dc.b	' 後方向検索文字列:',0
searching_mes:
		.dc.b	'検索中',0
not_found_mes:
		.dc.b	'見つかりません',0
isearch_mes_1:
		.dc.b	'isearch [',0
isearch_mes_2:
		.dc.b	']:',0

window_title:
		.dc.b	' Console driver Type-D v',VERSION,KEYBIND_TYPE,' - Multi scroll window '
WINDOE_TITLE_LEN:	.equ	$-window_title
		.dc.b	0

write_file_prompt:
		.dc.b	' ファイル書き出し:',0
insert_file_prompt:
		.dc.b	' ファイル読み込み:',0
disk_notready_mes:
		.dc.b	'ディスクが未挿入です',0
		.even
file_io_disable_mes:
		.dc	0
		.dc.b	'力不可能なデバイスです',0

fopen_err_mes_tbl:
		.dc.b	$fe,'ファイルが存在しません',0
		.dc.b	$fd,'ディレクトリが存在しません',0
		.dc.b	$fc,'FCB が不足しています',0
		.dc.b	$fb,'ディレクトリ/ボリュームラベルはオープン出来ません',0
		.dc.b	$f3,'ファイル名が異常です',0
		.dc.b	$f1,'ドライブ名が異常です',0
		.dc.b	$ed,'書き込み不可能なファイルです',0
		.dc.b	$e9,'ディスクの容量が不足しています',0
		.dc.b	$e8,'ディレクトリに空きがありません',0
		.dc.b	$df,'ファイルがロックされています',0
		.dc.b	$dd,'シンボリックリンクのネストが深すぎます',0
fopen_err_mes:	.dc.b	$00,'ファイルがオープン出来ません(その他のエラー)',0

toggle_buffer_mode_mes:
		.dc.b	'設定変更(B:BS処理 C:制御記号削除 E:ESC削除 I:TAB変換 T:Tab表示 R:改行表示 X:検索モード):',0
toggle_text_mode_mes:
		.dc.b	'設定変更(1:マウス制御 2:テキスト保存 3:テキスト使用状況無視 4:カーソル制御抑制):',0
set_mark_mes:
		.dc.b	'set-mark.',0


		.ifndef	__EMACS
define_label_mes:
		.dc.b	'ラベル定義(',0
jump_label_mes:
		.dc.b	'ラベルジャンプ(',0
label_mes_end:
		.dc.b	'):',0
		.endif

		.ifdef	__EMACS
no_mark_err_mes:
		.dc.b	'マークが設定されていません',0

prefix_meta_mes:	.dc.b	'Meta',0
prefix_ctrlx_mes:	.dc.b	'C-x',0

ise_fnc_tbl:
		.dc.b	21,$ff,1,0		ROLL UP
		.dc.b	22,$ff,2,0		ROLL DOWN
		.dc.b	24,$ff,3,0		DEL
		.dc.b	25,$ff,4,0		↑
		.dc.b	26,$ff,5,0		←
		.dc.b	27,$ff,6,0		→
		.dc.b	28,$ff,7,0		↓
		.dc.b	29,$ff,8,0		CLR
		.dc.b	30,$ff,9,0		HELP
		.dc.b	31,$ff,10,0		HOME
		.dc.b	32,$ff,11,0		UNDO
		.dc.b	0

		.endif

ctrl2scan_table:
	.irpc	%a,＠ABCDEFGHIJKLMNOPQRSTUVWXYZ［＼］＾_
		.dc.b	KEY_%a
	.endm
	.dc.b	KEY_SPACE
	.irpc	%a,！”＃＄％＆’（）＊＋，－．／0123456789：；＜＝＞？
		.dc.b	KEY_%a
	.endm


* 数値データ等 -------------------------------- *

		.quad
text_address:	.dc.l	$e60400			;バックスクロールウィンドウの左上アドレス
text_ras_no:	.dc	$202			;ラスタ番号
down_line:	.dc	0			;下に移動した行数
window_line:	.dc	28			;バックスクロールウィンドウの行数-1

putbuf_column:	.dc.b	WIDTH			;バッファ書込桁数

default_paste_header:
		.dc.b	'>'
option_f_col:	.dc.b	3			;IOCS _B_PUTMES の色
option_o_flag:	.dc.b	2


* タブ/改行記号フォント ----------------------- *

	.ifdef	__EM_FONT_TAB

* TAB 開始フォント
tab_font_1:
		.dc.b	%00000000		;MicroEMACS フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00011000
		.dc.b	%00010100
		.dc.b	%00011000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
* TAB フォント
tab_font_2:
		.dc.b	%00000000		;MicroEMACS フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00011000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
	.else
tab_font_1:
		.dc.b	%00000000		;オリジナル フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00100000
		.dc.b	%00110000
		.dc.b	%00111000
		.dc.b	%00111100
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
tab_font_2:
		.dc.b	%00000000		;オリジナル フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00010000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
**		.dc.b	%00000000
	.endif

	.ifdef	__EM_FONT_CR
* 改行フォント
cr_font:
		.dc.b	%00000000		;MicroEMACS フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00111100
		.dc.b	%00100100
		.dc.b	%00100100
		.dc.b	%00100111
		.dc.b	%00100010
		.dc.b	%00100100
		.dc.b	%00101000
		.dc.b	%00110000
		.dc.b	%00100000
		.dc.b	%00000000
	.else
cr_font:
		.dc.b	%00000000		;オリジナル フォント
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00000000
		.dc.b	%00111000
		.dc.b	%00111000
		.dc.b	%00111110
		.dc.b	%00111100
		.dc.b	%00111000
		.dc.b	%00110000
		.dc.b	%00000000
		.dc.b	%00000000
	.endif


* ヘルプ -------------------------------------- *

		.even
help_mes_top:
		.dc.b	0
		.ifdef	__EMACS
			.include	condrv_help_em.s
		.else
			.include	condrv_help.s
		.endif
help_mes_last_ofst:
		.dc.b	0			最後の行の長さは 0 バイト
help_mes_last_ptr:
		.dc.b	0			空行
help_mes_end:
*		.dc.b	0			最後の行の長さ その２(なくても平気だろう...

		.quad
*		.dc.l	'hmk*'			;識別子
help_buf_struct:
		.dc.l	help_mes_top		バッファ先頭
		.dc.l	help_mes_top		リングバッファの先頭
		.dc.l	help_mes_last_ofst	現在行の先頭
		.dc.l	help_mes_last_ptr	書き込みポインタ
		.dc.l	help_mes_end+1		バッファ末尾+1
*		.ds.l	2

HOOKTBL:	.macro	funcno,newadr
		.dc	BASE+.low.funcno*4,newadr-top_
		.endm

* 文字種テーブル ------------------------------ *

		.quad
ctype_table:
i:=0
		.rept 256
		v:=  (($80<=i&i<=$9f).or.($e0<=i&i<=$ff))&1<<IS_MB_bit
		v:=v|(('0'<=i&i<='9').or.('A'<=i&i<='F').or.('a'<=i&i<='f'))&1<<IS_HEX_bit
		v:=v|('0'<=i&i<='9')&1<<IS_DEC_bit
		.dc.b v
		i:=i+1
		.endm

* ベクタを変更するリスト ---------------------- *
* 使用後はロングワードで元のアドレスを待避
		.quad
hook_table_top:

BASE:		.set	$400
b_keyinp_orig:	HOOKTBL	_B_KEYINP	,iocs_b_keyinp
b_keysns_orig:	HOOKTBL	_B_KEYSNS	,iocs_b_keysns
key_init_orig:	HOOKTBL	_KEY_INIT	,iocs_key_init
b_putc_orig:	HOOKTBL	_B_PUTC		,iocs_b_putc
b_print_orig:	HOOKTBL	_B_PRINT	,iocs_b_print
txrascpy_orig:	HOOKTBL	_TXRASCPY	,iocs_txrascpy

BASE:		.set	$1800
hendsp_orig:	HOOKTBL	_HENDSP		,dos_hendsp
fnckey_orig:	HOOKTBL	_FNCKEY		,dos_fnckey
conctrl_orig:	HOOKTBL	_CONCTRL	,dos_conctrl

		.dc	0		* end of table

* Block Storage Section ----------------------- *

		.bss
		.quad

		.ifndef	__EMACS
label_buffer:	.ds.l	26
		.endif
xcon_req_adr:	.ds.l	1
		.ifdef	__XCONC
xconc_req_adr:	.ds.l	1
		.endif

fepctrl_lock:	.ds.l	1
fepctrl_mode:	.ds.l	1
last_time:	.ds.l	1
mes_end_adr:	.ds.l	1
io_buffer:
fnckey_buf:
line_store_buf:	.ds.b	TEXTSAVESIZE	行入力時の元のテキスト保存バッファ
case_table:	.ds.b	256		半角小文字->大文字変換テーブル
search_string:	.ds.b	GETSMAX+1	大文字化した検索文字列(2文字目以降)

sys_stat_prtbuf:
		.ds.b	1			'!'表示用バッファ
paste_header:
		.ds.b	1
search_string_buf:
		.ds.b	GETSMAX+1		検索文字列バッファ
isearch_string_buf:
		.ds.b	GETSMAX+1

		.even
cursor_blink_count:
		.ds.b	1
cursor_blink_state:
		.ds.b	1
iocs_curflg:
		.ds.b	2			IOCSwork待避buffer($992-$993:_OS_CURON/OFF)
bitflag:
		.ds.b	1			各種フラグ
HELPMODE_bit:	.equ	7 : ヘルプモード
AFTERCR_bit:	.equ	6 : 改行直後:ペーストヘッダ出力用
FEPOPEN_bit:	.equ	5 : 漢字変換窓オープン中
**GETSS_bit:	.equ	4 : 一行入力中
ISEARCH_bit:	.equ	4 : 遂次検索で一文字入力直後(C-s,C-r等の次検索時は0になる)
NO_FUNC_bit:	.equ	3 : ファンクションキー"非"表示中("!>"表示不可能フラグ)
SUSPEND_bit:	.equ	2 : バックスクロール画面を開いたまま終了
BUFINIT_bit:	.equ	1 : バッファ初期化済み:組み込み時の"～を初期化しました"表示用
BACKSCR_bit:	.equ	0 : バックスクロールモード
IS_HELPMODE:	.equ	%1000_0000
IS_AFTERCR:	.equ	%0100_0000
IS_FEPOPEN:	.equ	%0010_0000
**IS_GETSS:	.equ	%0001_0000
IS_ISEARCH:	.equ	%0001_0000
IS_NO_FUNC:	.equ	%0000_1000
IS_SUSPEND:	.equ	%0000_0100
IS_BUFINIT:	.equ	%0000_0010
IS_BACKSCR:	.equ	%0000_0001

		.quad
text_pal_buff:	.ds	16			テキストパレット待避バッファ

vdisp_int_adr:	.ds.l	1			垂直同期割り込みでフックするアドレス
ras_int_adr:	.ds.l	1			ラスタ割り込みでフックするアドレス

line_buf:	.ds.l	29			表示中の行のバッファアドレス
buffer_size:	.ds.l	1			バッファ容量-32bytes(管理情報の分)
;挿入禁止
mark_char_adr:	.ds.l	1			マーク開始位置
mark_line_adr:	.ds.l	1			マーク開始行のバッファアドレス
;挿入禁止
cursorX:	.ds	1			バックログのカーソルＸ座標
cursorXbyte:	.ds	1			バックログの行の左端からのバイト数
cursorY:	.ds	1			バックログのカーソルＹ座標
;挿入禁止
curx_save:	.ds	1			;保存したカーソルＸ座標

* 検索成功時にセットされる. 失敗したらsearch_char_adrがクリアされる.
search_char_adr:.ds.l	1			;カーソル位置のバッファアドレス
search_x:	.ds	1			;カーソルＸ座標
search_xbyte:	.ds	1			;行の左端からのバイト数

last_line_ptr:	.ds.l	1			;&line_buf[last_line]
last_line_adr:	.ds.l	1			; line_buf[last_line]
last_line_byte:	.ds.b	1			;*line_buf[last_line]

stop_level_char:.ds.b	1			;0 or '1'～'9'

;XCON への出力の状態
		.quad
xcon_output_st:	.ds.l	1
xcon_output_hb:	.ds.b	1			;2バイト文字の上位バイト
xcon_output_d0:	.ds.b	1			;$1b=エスケープシーケンス中なら

bufwrite_last:	.ds	1			前回の書き込み文字
bufmod_stack:	.ds.l	1
bufmod_height:	.ds.b	1
no_mem_flag:
gm_automask:	.ds.b	1			;許可→禁止にしているなら$ff
gm_maskflag:	.ds.b	1
ms_ctrl_flag:	.ds.b	1			マウス制御をした時に-1
skeymod_save:	.ds.b	1			以前のソフトキーボード状態
mscur_on_flag:	.ds.b	1			マウスカーソルを消去した時-1(後で表示する)
sleep_flag:	.ds.b	1
curx_save_flag:	.ds.b	1			;直後にカーソル位置を保存しない

		.ifdef	__EMACS
prefix_flag:	.ds.b	1
isearch_flag:	.ds.b	1
		.else
ins_clr_flag:	.ds.b	1
		.endif

option_m_flag:	.ds.b	1			;bit3=1:カーソル制御しない
						;bit2=1:TUSEMD無視
						;bit1=1:Plane2/3保存
						;bit0=1:Mouse制御
option_p_flag:	.ds.b	1
option_r_flag:	.ds.b	1
option_t_flag:	.ds.b	1
option_x_flag:	.ds.b	1

option_nb_flag:	.ds.b	1
option_nc_flag:	.ds.b	1
option_ne_flag:	.ds.b	1
option_nt_flag:	.ds.b	1

		.quad
paste_pointer:
		.ds.l	1		ペースト位置
backscroll_buf_adr:
		.ds.l	1		バッファ先頭アドレス
keypaste_buffer:
		.ds.b	KBbuf_Default

end_:
		.end	command_exec

# 公開ワークの構造
	.dc.b	-j(bit7),-f(bit0) フラグ
	.dc.b	0			.even???
	.dc	ペーストのウェイトカウンタ
	.dc		〃	初期値
	.dc.l	システムコールのアドレス
	.dc.b	0			未使用???
	.dc.b	ウィンドウキー抑制フラグ(-1:抑制)
	.dc.l	バッファ書き込みルーチンのアドレス
	.dc.l	キーボードバッファの長さ
	.dc.l	キーボードバッファの先頭アドレス
	.dc.l	識別子'hmk*'
* IOCS _KEY_INIT

# キーボードバッファ周辺の構造
	.dc.l	ペースト開始アドレス
	.dc.l	バックログバッファのアドレス
* ペーストバッファ

* End of File --------------------------------- *
