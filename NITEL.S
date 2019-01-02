

Out_RS		macro	\1
		lea \1,a1
		bsr RS_OUTSTR
		endm

Out_Nitel	macro	\1
		lea \1,a1
		moveq #2,d0
		move fl_cx,d7
		trap #8
		endm



	include macro2.s
	include	gemmacro.s


start
*	D‚but de l'execution
	clr.w Mag_Len
	clr.l Mag_Buf
	clr.l PagePtr
	clr.b PageBuf

	lea mystack,a7

*	Initialisation de PathBuf :
	curdisk
	and #$0f,d0
	add #'A',d0
	move.b d0,Path_buf


*	On signale l'installation !
	pea demar0s(pc)
	push #9
	trap #1
	addq #6,sp


*	Initialiser la RS :
	push #-1
	push #-1
	push #-1
	push #%10101110
	push #0
	push #7
	push #15
	trap #14
	add #14,sp


*	Augmenter la taille du buffer de la RS :
	push #0
	push #14
	trap #14
	addq #4,sp

	move.l d0,a1
	lea RS_XBuf,a0
	move.l a0,(a1)+
	move #4000,(a1)+
	clr (a1)+
	clr (a1)+
	move #3990,(a1)+
	move #3990,(a1)+


*	D‚marrage application !
	appl_init
	move.w	d0,ap_id		store the application id


*	On cr‚e le choix dans le menu :
	menu_register ap_id,#Nom_Appli
	move d0,menu_id


	graf_handle
	move.w	d0,current_handle	Desktop's VDI handle


* start by opening a virtual workstation
	lea	intin,a0
	moveq	#10-1,d0		-1 for DBF
fill	move.w	#1,(a0)+		most params are 1
	dbf	d0,fill
	move.w	#2,(a0)+		use RC system

	v_opnvwk			open it

* we want to open a window, so find the usable size of the screen
	wind_get	#0,#4		work area of Desktop

* the type of the window
wtype	equ %000000001011		title(1), close(2), full(4), move(8)

* the size lies in int_out(1..4), so calculate the window size
	movem.w	int_out+2,d0-d3
	wind_calc	#wtype,#1,d0,d1,d2,d3	want work area

* now remember its offsets
	move.w int_out+2,xstart
	move.w int_out+4,ystart
	move.w int_out+6,xwidth
	move.w int_out+8,ywidth

*	Sauve les coordonn‚es courantes !
	movem xstart,d0-d3
	movem d0-d3,WinAct
	movem d0-d3,FullWin

*	Fenetre ferm‚e lors du lancement de l'application :
	move #-1,w_handle


*	Initialisation TRAP8 virtuel : absolument !
	Out_Nitel ClrWin1(pc)
	Out_RS ClrWin3(pc)


*	Page ...
	Out_Nitel La_Page

*	La suite : pointeurs sur ecrans virtuels
	moveq #-1,d0
	trap #8
	move.l d0,vscreen		*Virtual Screen en BitMap
	move.l d1,ascreen		*Virtual Screen en Ascii
	move.l d2,vscr2



* the main loop of the application
* the only interesting events are messages
waitforevent
	bsr Evenements

*	D0=masque de r‚sultats :
	btst #0,d0
	beq.s no_kbd
	push d0
	move int_out+10,d0
	BSR Keyboard_manager
	pop d0
no_kbd

	btst #5,d0
	beq.s no_timer
	push d0
	bsr Read_RS
	pop d0
no_timer

*	S'agit-il d'un clic de la souris ???
	btst #1,d0
	beq.s no_button
	push d0
	bsr Mouse_Manager
	pop d0
no_button

	btst #4,d0
	beq waitforevent

*	Tracing...2
*	moveq #'>',d0
*	bsr rs_outcar
*	move messagebuf,d0
*	bsr rs_out2hex
*	moveq #'<',d0
*	bsr rs_outcar
*	bsr rs_outspace


	lea	messagebuf,a0
	move.w	(a0),d0			message type
	cmp.w	#20,d0
	beq	updateit			if Redraw
	cmp.w	#22,d0
	beq	CloseIt			if Close button
	cmp.w	#28,d0
	beq	moveit			if window moved
	cmp.w	#23,d0
	beq	FullIt


*	Passage au top...
	cmp.w	#21,d0
	beq	TopIt
	cmp.w	#30,d0
	beq	TopIt

*	Ouverture/Fermeture :
	cmp.w	#40,d0
	beq	OpenIt
	cmp.w	#31,d0
	beq	KillIt
	cmp.w	#41,d0
	beq	KillIt


* nothing I'm interested in so try again
	bra	waitforevent

Win_State	dc	0
CloseIt
*	On la ferme ?!
	move 6(a0),d0
	cmp w_handle,d0
	bne WaitForEvent

	move Win_State(pc),d0
	beq WaitForEvent		*Deja ferm‚ !
	clr Win_State

	Wind_Close	W_handle
	Wind_Delete	w_handle
	move		#-1,w_handle
	bra WaitForEvent


Monos	dc.b	1,"[1][Attention !!!!|Nitel ne fonctionne|qu'en monochrome][ Dommage ]",0,0
	even


OpenIt
*	Ouverture de la fenetre :
	move Menu_Id,d0
	cmp 8(a0),d0
	bne WaitForEvent


*	Si...pas monochrome : alerte !
	push #4
	trap #14
	addq #2,sp
	cmp #2,d0
	beq.s OpenHit


	lea Monos(pc),a0
	bsr Alerte
	bra WaitForEvent


OpenHit
	move Win_state(pc),d0
	bne WaitForEvent
	move #-1,Win_State

*	Tableau...DEMO/200Hz
	bsr View_Tableau


*	C'est bien moua !
	move w_handle,d0
	bmi.s OpenIt0
	movem WinAct,d0-d3
	movem d0-d3,8(a0)
	bra TopIt			*Juste ‡a !


OpenIt0
*	On la cr‚e :
	movem.w	WinAct,d0-d3
	wind_create	#wtype,d0,d1,d2,d3
	move.w	d0,w_handle		save the handle (error checks?)

* now set its title
	move.l	#windowname,int_in+4
	wind_set	w_handle,#2	title string

* now actually show it by opening
	movem.w	FullWin,d0-d3
	add.w	#10,d0			x start
	add.w	#10,d1			y start
	move #322,d2
	move #270,d3			*Et paf !
	move d2,xstart+4		*New width
	move d3,xstart+6		*New Height
	movem d0-d3,WinAct

	wind_open	w_handle,d0,d1,d2,d3

	bsr Recalcwindow
	bra WaitForEvent


WinAct	dc.w	0,0,0,0,0,0,0,0
FullWin	dc.w	0,0,0,0,0,0,0,0


KillIt
*	Fermeture de l'accessoire par le bureau :
*	move 8(a0),d0
*	cmp Menu_Id,d0
*	bne WaitForEvent

	clr Win_State
	move #-1,w_handle
	bra WaitForEvent


TopIt
	move 6(a0),d0
	cmp w_handle,d0
	bne WaitForEvent

	movem WinACt,d0-d3
	movem d0-d3,8(a0)

*	On la place en haut de la pile...
	push.l a0
	wind_set	w_handle,#10
	pop.l a0

	bra ChangedWindow


* move the window around the screen
moveit	move.w	6(a0),d0
	cmp.w	w_handle,d0
	bne	waitforevent		if not my window then don't

changedwindow
*	Sauvegarde Fenetre actuelle :
	movem 8(a0),d0-d3
	movem d0-d3,WinAct

	move.w	8(a0),int_in+4		new x pos
	move.w	10(a0),int_in+6		new y pos
	move.w	12(a0),d0

	cmp #340,d0
	blo.s .woky
	move #340,d0
.woky	cmp.w	#64,d0
	bcc.s	.wok
	moveq	#64,d0			can't be too narrow

.wok	move.w	d0,int_in+8		width
	move.w	14(a0),d0
	cmp #288,d0			*Nouvelle taille !
	blo.s .hoky
	move #288,d0
.hoky	cmp.w	#64,d0
	bcc.s	.hok
	moveq	#64,d0			can't be too thin either
.hok	move.w	d0,int_in+10		height

	wind_set	w_handle,#5

	movem.w	xwidth,d4-d5		old size
	bsr	recalcwindow
	cmp.w	xwidth,d4
	bcs	waitforevent
	cmp.w	ywidth,d5
	bcs	waitforevent
	bne.s	forceupdate
	cmp.w	xwidth,d4
	beq	waitforevent		not if exactly the same

* if the new size is smaller in both dimensions than the old size
* then an update event will not be posted, so the re-draw will
* have to be done manually
forceupdate
	bsr	drawwindow		draw it
	bra	waitforevent		and carry on

* re-size the window
sizeit	move.w	6(a0),d0
	cmp.w	w_handle,d0
	bne	waitforevent		if not my window
	bra	changedwindow

* there's an update
updateit
	move.w	6(a0),d0
	cmp.w	w_handle,d0
	bne	waitforevent		if not my window

* there are two ways of doing updates:
* (a) to support overlapping windows
* this takes a lot of code, and is very slow and tricky
* (b) to ignore the possibility of overlapping windows
* this takes little code and is easy
* Here method (b) is used! (method (a) is needed if you have a Desk
* menu or multi-windows in your program - this doesn't have either
* -that's my excuse and I'm sticking to it!)

* start by clipping the rectangle
	movem.w	8(a0),d0-d3		the rectangle

	add.w	d0,d2
	add.w	d1,d3

	vs_clip	#1,d0,d1,d2,d3		clipping on

	bsr	drawwindow			draw the window
	bra	waitforevent

* the full button has been clicked
* this puts up an alert box
fullit
	move 6(a0),d0
	cmp w_handle,d0
	bne WaitForEvent
	bra WaitForEvent

*	Essai de Raster Copy Transparent...hum !
	lea ptsin,a0
	move #10,(a0)+
	move #10,(a0)+
	move #410,(a0)+
	move #110,(a0)+
	move #20,(a0)+
	move #120,(a0)+
	move #420,(a0)+
	move #220,(a0)+

	vrt_cpyfm #3,#LeMFDB,#LeMFDB,0,1
	conin
	bra	ChangedWindow

*	Faus MFDB....enfin presque...
LeMFDB
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0

quit
* to go away various things have to be tidied up

*	D‚connexion...
	OUT_RS ESC9g

* starting with closing the window
	wind_close	w_handle	close it
	wind_delete	w_handle	and delete it

* then closing the virtual workstation
	v_clsvwk			close it

	appl_exit			tell GEM I've finished

* now quit to the desktop
	clr.w	-(a7)			status code
	move.w	#$4c,-(a7)		P_TERM
	trap	#1			and go away

* calculate the work area of the window
recalcwindow
	wind_get	w_handle,#4	get work area
	movem.w	int_out+2,d0-d3
	movem.w	d0-d3,xstart
	rts


fl_mouse	dc	0
* this draws the picture in the window
* which is an oval on top of a rectangle


Write_CF
*	Mode monochrome ?!
	push #4
	trap #14
	addq #2,sp
	cmp #2,d0
	bne.s Write_CFX


*	Transfert RAM Video :
	push #2
	trap #14
	addq #2,sp
	move.l d0,a1
	move.l vscreen(pc),a0

	lea 38(a0),a0			*Sur ti'C/F
	lea 78(a1),a1
	moveq #-1,d0
	moveq #10-1,d1
	move d0,(a1)
	move d0,80(a1)
	move d0,160(a1)
	lea 240(a1),a1
Write_CF0
	move.b (a0),d2
	lea 80(a0),a0
	asl #4,d2
	or #%1111000000001111,d2
	move d2,(a1)
	lea 80(a1),a1
	dbra d1,Write_CF0

	move d0,(a1)
	move d0,80(a1)
	move d0,160(a1)
Write_CFX
	rts


* before drawing anywhere you have to hide the mouse

drawwindow
*	De toute fa‡on on ‚cris le ti'C ou F :
	bsr Write_CF

	move w_handle,d0
	bmi draw_win0

	move int_out+6,d0
	and #3,d0
	beq.s goalx
draw_win0
	move #-1,fl_review
	rts

goalx
	clr fl_mouse

	WIND_UPDATE	#1

*	Doit-on la faire partir ???
	movem xstart,d0-d3
	add d0,d2
	add d1,d3
	add #32,d2
	add #32,d3
	sub #16,d0
	sub #32,d1

	move int_out+2,d4
	cmp d4,d2
	blo.s goaly
	tst d0
	bmi.s goalx0
	cmp d4,d0
	bhi.s goaly
goalx0
	move int_out+4,d4
	cmp d4,d3
	blo.s goaly
	tst d1
	bmi.s goalx1
	cmp d4,d1
	bhi.s goaly
goalx1


	v_hide_c			hide the mouse

	move #-1,fl_mouse
goaly

*	Quel ‚ran virtuel choisir ???
	move.l vscreen,a0
	move.l Blink_Count,d0
	and #1,d0
	beq.s Goal_Scr1
	move.l vscr2,a0
Goal_Scr1
	move.l a0,ScrPtr

*	On prends les coordonn‚es RASTER de l'‚cran de travail
	WIND_GET	w_handle,#4
	movem int_out+2,d0-d3
	movem d0-d3,WorkSpace

	WIND_GET	w_handle,#11
Redraw_Loop
*	Fini ?!
	move int_out+6,d0
	or int_out+8,d0
	beq Redraw_Quit

*	Adresse de l'ecran :
	push #2
	trap #14
	addq #2,sp
	move.l d0,a2				*But Ptr

*	Nouveau redraw : bit-mapped !
	movem int_out+2,d0-d3
	move.l ScrPtr,a0

*	Limite en Y :
	cmp #400,d1
	bhs.s skip0

	move d1,d4
	add d3,d4
	cmp #400,d4
	blo.s goal1
	move #400,d3
	sub d1,d3
goal1

*	Limite en X :
	cmp #640,d0
	bhs.s skip0

	move d0,d4
	add d2,d4
	cmp #640,d4
	blo.s gola1
	move #640,d2
	sub d0,d2
gola1


*	Transferts et calculs :
	move d2,d4
	move d3,d5
	move d0,d2
	move d1,d3
	sub WorkSpace,d0
	sub WorkSpace+2,d1

	bsr BitMap_Copy

skip0

*	Au suivant :
	WIND_GET	w_handle,#12
	bra Redraw_Loop


Redraw_Quit
	clr fl_review				*R‚affich‚ !

	clr DeltaCount			*Compteur de temps !

	tst fl_mouse
	beq.s skip1

* we have finished drawing so get the mouse back
	v_show_c	#0		*show the mouse actually !
skip1
*	On rend la main :
	WIND_UPDATE	#0

	rts


*	Espace de travail :
WorkSpace	dc.w	0,0,0,0,0,0,0,0
		even


BitMap_Msk0
*	Tableau des masques de d‚but (2 exp n)
	dc.w	$ffff,$7fff,$3fff,$1fff,$0fff,$07ff,$03ff,$01ff
	dc.w	$00ff,$007f,$003f,$001f,$000f,$0007,$0003,$0001
	dc.w	$0000
BitMap_MSK1
*	Tableau des masques de fin :
	dc.w	$0000
	dc.w	$8000,$C000,$E000,$F000,$F800,$FC00,$FE00,$FF00
	dc.w	$FF80,$FFC0,$FFE0,$FFF0,$FFF8,$FFFC,$FFFE,$FFFF
	even


fl_loupe	dc	0


BitMap_Copy
*	Ligne d'origine des trac‚s r‚els :
	push d1

*	Copie (D0,A0) en (D1,A1) dimension (D2,D3)
	mulu #80,d1
	mulu #80,d3
*	add d1,a0
	add d3,a2
	move d0,d1
	move d2,d3
	lsr #4,d1
	lsr #4,d3
	add d1,d1
	add d3,d3
	add d1,a0
	add d3,a2
	and #15,d0
	and #15,d2

	lea BitMap_MSK0(pc),a1
	move d2,d3
	add d3,d3
	move 0(a1,d3.w),d3

	move d2,d1
	add d4,d1
	cmp #16,d1
	blo.s One_Column
Two_Columns
*	Au moins deux colonnes donc :
	sub #16,d1
	move d1,d6
	lsr #4,d1			*Nombre de Words...

	and #15,d6
	add d6,d6
	lea BitMap_MSK1(pc),a1
	move 0(a1,d6.w),d6
	bra.s Columns

One_Column
*	Une seule colonne avec masque bifide !
	move d1,d6
	moveq #-1,d1			*Flag
	and #15,d6
	add d6,d6
	lea BitMap_MSK1(pc),a1
	and 0(a1,d6.w),d3

Columns
*	Suite de la partie commune...Calcul Nrotations
	sub d2,d0
	neg d0

*	Transferts de Registres :
	exg d1,d3
	move d6,d2
	move d5,d4

*	Boucle r‚elle :
BitMap_Loop
	push.l a0
	move 4(sp),d7

	cmp #10,d7
	blo.s BitMap_L0
	cmp #250,d7
	bhs.s BitMap_L0

	move fl_loupe,d6
	beq.s BitMap_L0

	add #10,d7			*Pour la division par 2...
	dec d6
	beq.s BitMap_L1
	add #240,d7			*120 Video lignes plus bas
BitMap_L1
	lsr #1,d7
BitMap_L0
	mulu #80,d7
	add d7,a0
	inc 4(sp)

	bsr BitMap_CopyLine
	pop.l a0
	lea 80(a2),a2
	dec d4
	bne.s BitMap_Loop

	addq #2,sp			*Enleve la variable locale

*	Et on revient...
	rts


BitMap_CopyLine
	tst d0
	bmi.s CL_on0
	move (a0),d5
	lsr d0,d5
	bra.s CL_on1

CL_on0
*	Dans l'autre sens !
	move.l (a0),d5
	neg d0
	asl.l d0,d5
	neg d0
	swap d5
CL_on1
	and d1,d5
	move d1,d6
	not d6
	and (a2),d6
	add d6,d5
	move d5,(a2)

*	Mono_Colonne !!!
	tst d3
	bpl.s CL_TWO
	rts

CL_TWO
*	On fais le centre...
	lea (a0),a1
	lea 2(a2),a3
	move d3,d5
	dec d5

	tst d0
	bmi.s CL_two1
CL_two2
	tst d5
	bmi.s CL_two4
CL_two3
	move.l (a1),d6
	addq #2,a1
	lsr.l d0,d6
	move d6,(a3)+
	dbra d5,CL_two3
CL_two4
*	On fini a la main !
	move.l (a1),d6
	lsr.l d0,d6
	and d2,d6
	move d2,d7
	not d7
	and (a3),d7
	add d6,d7
	move d7,(a3)
*	Et hop...
	RTS


CL_two1
	neg d0
	tst d5
	bmi.s CL_TWO5
CL_two0	addq #2,a1
	move.l (a1),d6
	asl.l d0,d6
	swap d6
	move d6,(a3)+
	dbra d5,CL_two0
CL_TWO5
	addq #2,a1
	move.l (a1),d6
	asl.l d0,d6
	swap d6
	and d2,d6
	move d2,d7
	not d7
	and (a3),d7
	add d6,d7
	move d7,(a3)
	neg d0
	rts



Mouse_state	dc	0

M1inout		dc	0
x1	dc	0
y1	dc	0
w1	dc	0
h1	dc	0

M2inout		dc	0
x2	dc	0
y2	dc	0
w2	dc	0
h2	dc	0


*	EVNT_MULTI … la main !!!
Evenements
	lea int_in,a0		*Remplissage s‚quentiel
	move #%00110011,(a0)+		*Mflags
	move #1,(a0)+			*1 Clic suffit quoi !
	move #1,(a0)+			*Gauche
	move mouse_state,d0
	eor #1,d0
	move d0,(a0)+			*Attente changement d'‚tat !
	move m1inout,(a0)+		*Attente IO boite 1
	move x1,(a0)+
	move y1,(a0)+
	move w1,(a0)+
	move h1,(a0)+
	move m2inout,(a0)+		*Attente IO boite 2
	move x2,(a0)+	
	move y2,(a0)+
	move w2,(a0)+
	move h2,(a0)+
	move #0000,(a0)+		*Low  Time Count
	move #0000,(a0)+		*High Time Count

	lea messagebuf,a1
	move.l a1,addr_in			*GPBUF ?!

*	Appel r‚el
	AES 25

*	Retour...
	rts


Fl_Review	dc	-1
RS_BUF	dc.l	0,0,0,0,0,0,0,0
	even

Reaffiche
	bra drawwindow

Retour_RS
	cmp #85,DeltaCount
	bhi.s Reaffiche

	tst fl_review
	bne.s Reaffiche

	rts


Read_RS
*	Et paf : inactivation...
	tst v_Actif
	beq Retour_Rs


*	Si Delta_Time > 10s, on flush !
	move Mag_fl(pc),d0
	cmp #2,d0
	bne.s Read_RT
	move Mag_Len(pc),d0
	beq.s Read_RT
	move.l Mag_Timer(pc),d0
	cmp.l #200*10,d0
	blo.s Read_RT
	bsr Flush				*Vidage disque !
Read_RT


*	Si Play et pas pause :
	move mag_fl(pc),d0
	cmp #1,d0
	bne.s Read_RU
	move Mag_Pause(pc),d0
	bne.s Read_Ru

*	Si Mag_Timer2=0
	move.l Mag_Timer2(pc),d0
	bne.s Read_Ru
	bsr Affiche
Read_RU


*	Et paf !
	push #$12
	trap #1
	addq #2,sp
	tst d0
	beq Retour_RS


Vide_RS
*	Vidage RS 232C :
	push #$12
	trap #1
	addq #2,sp
	tst d0
	beq Reaffiche


*	On va le prendre 
	push #$03
	trap #1
	addq #2,sp


	tst d0
	beq Vide_RS


	and #$00ff,d0			*Word Zero Extend
	moveq #0,d1			*Buffer length
	lea RS_BUF(pc),a0
	cmp #31,d0
	bhi.s RS000

*	Effacement Buffer RS :
	clr.l (a0)
	clr.l 4(a0)
	clr.l 8(a0)
	clr.l 12(a0)

RS000
	inc d1
	tst.b (a0)+
	bne.s RS000
	move.b d0,-1(a0)
	clr.b (a0)+
	clr.b (a0)+
	clr.b (a0)+
	clr.b (a0)+


	lea RS_BUF(PC),a0
	clr d0
	move.b (a0),d0
	cmp #31,d0
	beq RS_LOCATE
	cmp #27,d0
	beq RS_ESCAPE

	cmp #$13,d0
	beq RS_FN

	cmp #$16,d0
	beq RS_SS2
	cmp #$19,d0
	beq RS_SS2
	cmp #$12,d0
	beq RS_REP


RS_EMIT
*	Emission du paquet :
	Out_Nitel RS_BUF


*	Magnetoscope en RECORD et PAUSE relach‚e ???
	move mag_fl,d0
	cmp #2,d0
	bne.s RS_EMY
	move Mag_Pause,d0
	bne.s RS_EMY

*	Delta Time > 1s ?!
	cmp.l #50,Mag_Timer
	blo.s RS_EMY0
	bsr Mag_Delta
RS_EMY0
	lea RS_BUF(pc),a0
	bsr Mag_Write
	clr.l Mag_Timer
RS_EMY

	cmp #$0700,RS_BUF
	bne.s RS_EMX
	conout #7
RS_EMX

*	On le stocke dans le PageBuf :
	lea RS_BUF(pc),a0
	lea PageBuf,a1
	move PagePtr(pc),d0

RS_EM0
	cmp #4000,d0
	blo.s RS_EM1
RS_EM2
	clr d0
	clr.b 0(a1,d0.w)

RS_EM1
	move.b (a0)+,d1
	beq.s RS_EM3
	cmp.b #12,d1
	beq.s RS_EM2
	move.b d1,0(a1,d0)
	inc d0
	tst d1
	bne.s RS_EM0

RS_EM3
	move d0,PagePtr

	clr.l RS_BUF
	clr.l RS_BUF+4
	clr.l RS_BUF+8
	bra VIDE_RS


RS_LOCATE
	cmp #3,d1
	bne VIDE_RS
	bra RS_EMIT

RS_ESCAPE
	cmp #1,d1
	beq VIDE_RS

	clr d0
	move.b 1(a0),d0
	cmp.b #$3f,d0
	bhi RS_ESC9

*	Les cas sp‚ciaux !!!
	cmp.b #$20,d0
	beq.s RS_ESC20
	cmp.b #$21,d0
	beq.s RS_ESC20b

	cmp.b #$32,d0
	beq.s RS_ESC21

	cmp.b #$38,d0
	bhi.s RS_ESC0
	cmp #3,d1
	bne VIDE_RS
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS


*	Bizarre, j'ai dit bizarre ?!
RS_ESC20
*	ESC $20 + 2 codes
	cmp #4,d1
	bne VIDE_RS
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS
RS_ESC20b
*	ESC $21 + 3 codes
	cmp #5,d1
	bne VIDE_RS
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS


RS_ESC21
	cmp #2,d1
	bne VIDE_RS
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS

RS_ESC0
	sub #$36,d0
	cmp d0,d1
	bne VIDE_RS
	bra RS_EMIT

RS_ESC9
	cmp.b #$40,d0
	blo RS_EMIT
	cmp.b #$48,d0
	blo.s RS_ESC9a
	cmp.b #$50,d0
	blo RS_EMIT
	cmp.b #$57,d0
	bhi RS_EMIT
RS_ESC9a
*	Si noir et blanc : filtre ‡a !
	tst fl_white
	beq RS_EMIT
	clr.l RS_BUF
	clr.l RS_BUF
	bra VIDE_RS


RS_SS2
	cmp #2,d1
	blo VIDE_RS
	clr d0
	move.b 1(a0),d0
	cmp #$41,d0
	blo.s RS_SS2a
	cmp #$48,d0
	bhi.s RS_SS2a
	cmp #3,d1
	bne VIDE_RS
	bra RS_EMIT
RS_SS2a
*	Okay !
	bra RS_EMIT

RS_FN
	cmp #2,d1
	bne VIDE_RS

	cmp #$1353,RS_BUF
	bne.s RS_FN0a

	move fl_cx,d0
	beq.s RS_FN0

	clr fl_cx
	move.l #$14000000,RS_BUF
	out_nitel	RS_BUF		*Enleve le curseur !
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS

RS_FN0
	move #-1,fl_cx		*D‚but de connexion
	clr.l timecx
	clr.l		RS_BUF
	clr.l		RS_BUF+4
	out_nitel	RS_BUF		*Etat CX/DCX

RS_FN0a
	clr.l RS_BUF
	clr.l RS_BUF+4
	bra VIDE_RS


fl_cx	dc	0		*D‚connect‚ par d‚faut !


RS_REP
	move #-1,fl_cx

	cmp #2,d1
	bne VIDE_RS
	bra RS_EMIT


RS_OUTSTR
	clr.l d0
	move.b (a1)+,d0
	beq.s RS_OUTST0
	push.l a1
	push d0
	push #$04
	trap #1
	addq #4,sp
	pop.l a1
	bra.s rs_outstr
rs_outst0
	rts

rs_outspace
	moveq #32,d0
rs_outcar
	push d0
	push #4
	trap #1
	addq #4,sp
	rts

RS_OUT2HEX
	push d0
	lsr #4,d0
	bsr RS_OUT1HEX
	pop d0
RS_OUT1HEX
	and #15,d0
	cmp #10,d0
	blo.s rs_out1hex0
	add #7,d0
rs_out1hex0
	add #'0',d0
	push d0
	push #4
	trap #1
	addq #4,sp
	rts


Keyboard_manager
*	Gestion du clavier :
	Lea kbd_correction,a0
	cmp.b #127,d0
	beq kbd_string
	bhi Kbd_accents			*Accentu‚s ST
	cmp.b #31,d0
	bhi KBD_DIRECT

*	Codes ascii <32
	lea kbd_Envoi,a0
	cmp.b #13,d0
	beq KBD_STRING
	lea kbd_Correction,a0
	cmp.b #8,d0
	beq kbd_string

	tst.b d0
	beq.s Kbd_Scanning
*	On envoie directos le code :
	push.l #0
	move.b d0,(sp)
	OUT_RS (sp)
	addq #4,sp
	bra Kbd_Skip

Kbd_Scanning
	move d0,d1
	lsr #8,d1
	lea Scan_table,a1
	lea Scan_Ptrs,a0
Kbd_loop
	move.b (a1)+,d2
	beq.s Kbd_End
	move.l (a0)+,d3
	beq.s Kbd_End
	cmp.b d1,d2
	bne.s Kbd_Loop

	move.l d3,a0
	Out_RS (a0)
	rts
Kbd_End
*	F2 : Loupe
	cmp #$3c00,d0
	beq Kbd_Loupe
	cmp #$5500,d0
	beq Kbd_Loupe

	cmp #$4000,d0
	beq Kbd_NitelOff
	cmp #$4100,d0
	beq Kbd_NitelOn

*	ALT-M : Magn‚toscope...
	cmp #$2700,d0
	beq Kbd_ALT_M

*	ALT-D : DiskFree
	cmp #$2000,d0
	beq Kbd_ALT_D
*	ALT-S : Sauver en vid‚otex
	cmp #$1f00,d0
	beq Kbd_ALT_S
*	ALT-A : Sauver en Ascii
	cmp #$1000,d0
	beq Kbd_ALT_A
*	ALT_C : Charger une page
	cmp #$2E00,d0
	beq Kbd_ALT_C
*	ALT_E : Emission d'une page (… 75bds)
	cmp #$1200,d0
	beq Kbd_ALT_E
*	ALT_W : Couleur/Noir&Blanc
	cmp #$2c00,d0
	beq Kbd_ALT_W
*	ALT_P : Printer (Hard Copy)
	cmp #$1900,d0
	beq Kbd_ALT_P

Kbd_Skip
*	Rien !
	rts

Kbd_Direct
	push d0
	push #4
	trap #1
	addq #4,sp
	rts
Kbd_string
	Out_RS (a0)
	rts

Kbd_NitelOff
*	Envoie chaine Off au nitel...
	Out_RS Nitel_Off_Str
	rts
Kbd_NitelOn
*	Envoie chaine On au nitel :
	Out_Rs Nitel_On_Str
	rts
Nitel_Off_str
	dc.b	12,$1f,'00',$18,10
	dc.b	27,$3b,$60,$58,$52
	dc.b	27,$3b,$60,$51,$5a
	dc.b	0
Nitel_On_Str
	dc.b	27,$3b,$61,$58,$52
	dc.b	27,$3b,$61,$51,$5a
	dc.b	0
	even

Kbd_Loupe
	lea fl_loupe,a0
	inc (a0)
	cmp #3,(a0)
	bne.s Kbd_Loup1
	clr (a0)
Kbd_Loup1
	move #-1,fl_review
	rts


Next_Page
*	Lecture de la suite !
	open #0,File_Name(pc)
	tst d0
	bpl.s NP00
	bsr Disk_Error
	clr Mag_Fl
	rts

NP00
	push d0
	Lseek #2,d0,#0
	move.l d0,d1
	pop d0

*	Apres ou = EOF ?
	clr.l d2
	move Mag_Len(pc),d2
	add.l Mag_Ptr(pc),d2
	cmp.l d2,d1
	bhs.s NP01
	bra.s NP00c

NP00b
*	Close it !
	pop.l d2
NP00cx
	pop d0
NP00c
	close d0

NP00a
*	End of Game...
	clr Mag_Fl
	lea Mag_Str12(pc),a0
	bsr alerte
	rts 

NP01
*	On lit la suite...
	push d0
	push.l d1
	push.l d2

	move.l d2,Mag_Ptr
	clr Mag_Len

	lseek #0,d0,d2

*	Longueur … lire :
	pop.l d2
	pop.l d1
	move (sp),d0
	sub.l d1,d2
	cmp.l #4096,d2
	blo.s NP02
	move.l #4096,d2
NP02
	lea Mag_buf,a0
	read a0,d2,d0
	tst.l d0
	bmi NP00b
	move.l d0,d2

	tst d0
	beq NP00cx
	lea Mag_buf,a0
	tst.b (a0)
	beq NP00cx
	clr.b 0(a0,d2.l)
	clr.b 1(a0,d2.l)
	clr.b 2(a0,d2.l)
	clr.b 3(a0,d2.l)
	clr.b 4(a0,d2.l)
	clr.b 5(a0,d2.l)
	clr.b 6(a0,d2.l)
	clr.b 7(a0,d2.l)

	pop d0
	close d0

*	Bon on revient...next...
	bra.s Affiche


Aff_Buf		Dc.l	0,0,0,0

Affiche
*	On envoie le prochain caractere sur le nitel [et la prise serie]
	lea Mag_Buf,a0
	move Mag_len(pc),d0
	clr d1
	move.b 0(a0,d0.w),d1
	beq Next_Page			*Passe a la page suivante !

	move fl_cx(pc),d2
	bne.s Affich01
*	Pret a recevoir ????
	push #$13
	trap #1
	addq #2,sp
	tst d0
	bne.s Affich00
*	rat‚ !
	rts

Affich00
*	On le balance sur la prise...
	push d1

	push d1
	push #4
	trap #1
	addq #4,sp

	pop d1

Affich01
*	Au suivant !
	inc Mag_len

*	Si < 32, on vide le buffer !
	cmp #31,d1
	bhi.s Affich02
	clr.l Aff_Buf
	clr.l Aff_Buf+4
Affich02

*	Emission ?!
	lea Aff_Buf(pc),a1
	moveq #0,d3			*Pas -1, car rajout !
Affich01a
	inc d3
	tst.b (a1)+
	bne.s Affich01a
	move.b d1,-1(a1)
	clr.b (a1)

	move.b Aff_Buf(pc),d2
*	Et longueur actuelle dans d3
	cmp.b #31,d2
	beq.s Affich10			*Locate (3 cars)
	cmp.b #27,d2
	beq.s Affich20
	cmp.b #$13,d2
	beq Affich30

	cmp.b #$19,d2			*les 2 SS2...
	beq Affich40
	cmp.b #$16,d2
	beq Affich40

	cmp.b #$12,d2
	beq Affich50

Affich90
*	On le re-emet :
	Out_Nitel Aff_Buf(pc)

*	On le stocke dans le PageBuf :
	lea Aff_Buf(pc),a0
	lea PageBuf,a1
	move PagePtr,d0

AFF_EM0
	cmp #4000,d0
	blo.s AFF_EM1
AFF_EM2
	clr d0
	clr.b 0(a1,d0.w)

AFF_EM1
	move.b (a0)+,d1
	beq.s AFF_EM3
	cmp.b #12,d1
	beq.s AFF_EM2
	move.b d1,0(a1,d0)
	inc d0
	tst d1
	bne.s AFF_EM0

AFF_EM3
	move d0,PagePtr

	clr.l Aff_BUf
	clr.l Aff_Buf+4
Affich_Skip
	rts

Affich10
*	Si pas 3 cars...skip !
	cmp #3,d3
	beq.s Affich90
	rts
Affich20
*	Si $20 ou $21 :
	cmp #1,d3
	beq.s Affich_Skip
	clr d0
	move.b Aff_buf+1,d0
	cmp.b #$20,d0
	beq.s Affich21
	cmp.b #$21,d0
	beq.s Affich22
	cmp.b #$39,d0
	beq.s Affich23
	cmp.b #$3A,d0
	beq.s affich24
	cmp.b #$3B,d0
	beq.s Affich25
	cmp #2,d3
	beq Affich90
Affich21
	cmp #4,d3
	beq Affich90
	rts
Affich22
	cmp #5,d3
	beq Affich90
	rts
Affich23
	cmp #3,d3
	beq affich90
	rts
Affich24
	cmp #4,d3
	beq Affich90
	rts
Affich25
	cmp #5,d3
	bne Affich_Skip
	cmp.b #$40,Aff_Buf+2
	bne Affich90
	clr d0
	clr d1
	move.b Aff_buf+3(pc),d0
	move.b Aff_Buf+4(pc),d1
	and #63,d0
	and #63,d1
	asl #6,d0
	add d1,d0
	mulu #20,d0
	move.l d0,Mag_Timer2
*	Right !
	clr.l Aff_Buf
	clr.l Aff_Buf+4
	rts
Affich30
*	Cas des Fnkeys :
	cmp #2,d3
	beq Affich90
	rts
Affich40
*	accents :
	cmp #3,d3
	beq Affich90
	cmp #2,d3
	bne Affich_Skip
	clr d0
	move.b Aff_Buf+1(pc),d0
	cmp.b #$40,d0
	bls Affich90
	cmp.b #$4C,d0
	bhs Affich90
*	Rien !
	Rts
Affich50
*	R‚p‚tition...
	cmp #2,d3
	beq Affich90
	rts


Mag_Delta
*	Ecriture Delta Time !
	move.l Mag_Timer(pc),d0
	divu #20,d0
	move d0,d1
	lsr #6,d0
	and #63,d0
	and #63,d1
	add #64,d0
	add #64,d1
	push.l #0
	push.l #$1b3b4000
	move.l sp,a0
	move.b d0,3(sp)
	move.b d1,4(sp)
	clr.l Mag_Timer
	bsr Mag_Write
	addq #8,sp			*Evidemment !
*	On skip !
	rts


Mag_Write
*	Ajout en fin de buffer :
	lea Mag_Buf(pc),a1
	move Mag_len(pc),d1
Mag_wr0
	move.b (a0)+,d0
	beq.s Mag_Wr1
	move.b d0,0(a1,d1.w)
	inc d1
	clr.b 0(a1,d1.w)
	bra.s Mag_wr0
Mag_wr1
	move d1,Mag_Len
	cmp #4096,d1
	bhs.s Flush
Flush99
*	Double emploi !
	rts

Flush
*	Vide le buffer sur disque !
	move Mag_FL(pc),d0
	cmp #2,d0
	bne Flush99			*Play ou Stop...
	move Mag_Pause(pc),d0
	bne Flush99			*Paused !
	Move Mag_Len(pc),d0
	beq Flush99			*Vide d‚ja !

*	Okay a l'action !
	open #2,Mag_File(pc)
	tst d0
	bmi Flush90			*Un tour de cochon !
	push d0

*	GOTO End of file !
	lseek #2,d0,#0

*	Write to End-Of-File :
	move (sp),d0
	clr.l d1
	move Mag_len(pc),d1
	Write #Mag_Buf,d1,d0
	pop d0
	close d0

*	Le timer...
	clr.l Mag_Timer

*	Est-ce a translater ???
	move Mag_Len(pc),d0
	cmp #4096,d0
	bhi.s Flush10			*oui !

	clr Mag_Len
	rts

Flush10
*	On transfere !
	sub #4096,Mag_Len
	lea Mag_Buf(pc),a0
	lea 4096(a0),a1
	move #1024-1,d0
Flush11
	move.l (a1)+,(a0)+
	dbra d0,Flush11

*	Finido !
	rts

Flush90
*	A voir...
	clr Mag_FL
	clr Mag_Pause
	move.l #-1,Mag_Timer
	cmp #-33,d0
	bne Disk_Error
*	Le salaud !
	lea Mag_Str23(pc),a0
	bra Alerte


Mag_Str00	dc.b	3,"[1][Le Magn‚toscope est arr‚t‚.][ Play | Record | Annul. ]",0,0
Mag_Str10	dc.b	1,"[0][ |  Magn‚toscope en lecture :   | ][ Stop | Pause | Annul. ]",0,0
Mag_Str11	dc.b	1,"[0][ |  Magn‚toscope en lecture :   | (En pause actuellement) ][ Stop |Unpause| Annul. ]",0,0
Mag_Str12	dc.b	1,"[1][ |  Magn‚toscope en lecture :   | EOF : Arret automatique ][  Okay  ]",0,0
Mag_Str20	dc.b	1,"[0][ | Magn‚toscope en enregistrement | ][ Stop | Pause | Annul. ]",0,0
Mag_Str21	dc.b	1,"[0][ | Magn‚toscope en enregistrement | (En pause actuellement) ][ Stop |Unpause| Annul. ]",0,0
Mag_Str22	dc.b	2,"[1][ | Magn‚toscope :                 | Ce fichier existe d‚ja ! ][ Effac. | Ajoute | Annul. ]",0,0
Mag_Str23	dc.b	1,"[3][ Magn‚toscope : | Le fichier d'enregistrement | est inaccessible ! ][ Arghl.. ]",0,0
	even


Mag_FL		dc	0
Mag_Pause	dc	0
Mag_File	ds.b	128
	even

Kbd_ALT_M
*	Magn‚toscope..En fonction des modes :
	move mag_fl(pc),d0
	cmp #1,d0
	beq Magneto_Read
	cmp #2,d0
	beq Magneto_Write

*	Bon on affiche la boite d'alerte !
	lea Mag_str00(pc),a0
	bsr alerte
	cmp #3,d0
	beq.s Kbd_ALT_M0
	cmp #2,d0
	beq.s Kbd_M_WRITE
	bra Kbd_M_READ

Kbd_ALT_M0
*	Mode=Stop, PAUSE enlev‚e !
	clr Mag_Fl
	clr Mag_Pause
	move.l #-1,Mag_Timer
	bra Kbd_Skip



Kbd_M_Write
	clr Mag_Len			;Un oubli ?!
	clr.l Mag_Buf

*	Pr‚paration de l'ecriture :
	FSEL_INPUT #Path_Buf,#Fname_Buf
	tst int_out+2
	beq Kbd_Skip				*Rat‚ !

*	On transfere path+name :
	bsr SET_FILENAME

*	Copie du nom :
	lea File_name(pc),a0
	lea Mag_File(pc),a1
Kbd_MW0
	move.b (a0)+,(a1)+
	bne.s Kbd_MW0
	clr.b (a1)+

*	Existe-t'il d‚ja ?
	OPEN #0,Mag_File(pc)
	cmp #-33,d0
	beq.s Kbd_MW1				*Cr‚ation !
	tst d0
	bpl.s Kbd_MW2

	bsr Disk_Error
	bra Kbd_ALT_M0

Kbd_MW2
*	Pour commencer dermons-le !
	close d0

*	on demande hein ?!
	lea mag_str22(pc),a0
	bsr alerte
	cmp #3,d0
	beq Kbd_ALT_M0				*Arret !
	cmp #2,d0
	beq Kbd_MW9				*Okay ... c'est tout bon !

Kbd_MW1
*	Creation et paf !
	push #0
	pea Mag_File(pc)
	push #$3c
	trap #1
	addq #8,sp
	tst d0
	bpl.s Kbd_MW3				*Fermeture now...

*	Scandale !!!
	bsr Disk_Error
	bra Kbd_Skip

Kbd_MW3
*	On ferme !
	close d0
Kbd_MW9
*	Passage en mode RECORD, PAUSE OFF :
	clr Mag_Pause
	move #2,Mag_FL
	clr.l Mag_Timer
	bra Kbd_Skip


Kbd_M_Read
*	Lecture now ???
	clr Mag_FL
	clr Mag_Pause
	clr Mag_Len		*na !

*	On demande !
	FSEL_INPUT #Path_Buf,#Fname_Buf
	tst int_out+2
	beq Kbd_Skip				*Rat‚ !

*	On transfere path+name :
	bsr SET_FILENAME

*	Copie du nom :
	lea File_name(pc),a0
	lea Mag_File(pc),a1
Kbd_MR0
	move.b (a0)+,(a1)+
	bne.s Kbd_MR0
	clr.b (a1)+

*	Existe-t'il d‚ja ?
	OPEN #0,Mag_File(pc)
	tst d0
	bpl.s Kbd_MR1
	bsr Disk_Error
	bra Kbd_Skip

Kbd_MR1
*	Il existe, chic !!!!

*	On va en prendre la longueur, comme ‡a...pour voir !
	push d0
	lseek #2,d0,#0
	move.l d0,this_length
	pop d0

*	Fermons-le, plus la peine...
	close d0
	clr.l Mag_ptr				*Et paf !

	move #1,Mag_FL
	clr.l Mag_Timer2			*Declenche tout !
	clr.l Aff_Buf
	clr.l Aff_Buf+4
	clr.l Mag_Buf
	clr Mag_len
	bra Kbd_Skip


Magneto_Read
*	Lecture ou pas ?!
	lea Mag_str10(pc),a0
	move Mag_Pause(pc),d0
	beq.s Magneto_rd00
	lea Mag_str11(pc),a0
Magneto_rd00
	bsr alerte

	cmp #3,d0
	beq Kbd_Skip
	cmp #1,d0
	beq Kbd_ALT_M0
	not Mag_Pause
	bra Kbd_Skip


Magneto_Write
*	Enregistrement now...
	lea Mag_str20(pc),a0
	move Mag_Pause(pc),d0
	beq.s Magneto_wr00
	lea Mag_str21(pc),a0
Magneto_wr00
	bsr alerte

	cmp #3,d0
	beq Kbd_Skip
	cmp #1,d0
	beq.s Magneto_Wr10

	not Mag_Pause
	bsr Flush				*Des fois que...

	bra Kbd_Skip
Magneto_Wr10
	bsr Flush
	bra Kbd_ALT_M0				*Finido !


This_Length	dc.l	0
Disk_Space	ds.l	8
DS00		dc.b	1,"[1][Le disque "
DS01		dc.b	".:  dispose de| "
DS02		dc.b    "----- Ko libres.]"
		dc.b	"[  Ok !  ]",0,0
		even

Alerte
*	Affichage de la form_alert (a0)+
	clr.l d0
	move.b (a0)+,d0

*	Appel de GEM :
	form_alert d0,a0
	move int_out,d0			*Pour le plaisir !
	rts



Kbd_ALT_D
*	Routine de calcul et d'affichage de l'espace disque restant :
	push #$19
	trap #1
	addq #2,sp
	push d0

*	Lettre du lecteur dasn la boite !
	lea ds01(pc),a0
	add #'A',d0
	move.b d0,(a0)

	pea Disk_Space(pc)
	push #$36
	trap #1
	addq #8,sp

*	Calcul now :
	lea Disk_Space(pc),a0
	move.l (a0),d0
	move.l 8(a0),d1
	move.l 12(a0),d2
	divu #512,d1			*Pour obtenir en secteur de 512..
	mulu d2,d0
	cmp #1,d1
	beq.s sect512			*Precision maximale !!!
	mulu d1,d0
sect512

*	Division par 2 pour Ko :
	lsr.l #1,d0

*	Ecriture dnas la zone a cet effet :
	lea DS02(pc),a0
	divu #10000,d0
	push.l d0
	add #'0',d0
	move.b d0,(a0)+
	pop.l d0
	clr d0
	swap d0
	divu #1000,d0
	push.l d0
	add #'0',d0
	move.b d0,(a0)+
	pop.l d0
	clr d0
	swap d0
	divu #100,d0
	push.l d0
	add #'0',d0
	move.b d0,(a0)+
	pop.l d0
	clr d0
	swap d0
	divu #10,d0
	add #'0',d0
	move.b d0,(a0)+
	swap d0
	add #'0',d0
	move.b d0,(a0)+

*	maintenant ‚liminons les '0' de tete !
	lea ds02(pc),a0
	moveq #4-3,d0
sect511
	cmp.b #'0',(a0)
	bne.s sect510
	move.b #32,(a0)+
	dbra d0,sect511
sect510

*	Maintenant la boite d'alerte !
	lea DS00(pc),a0
	bsr alerte

*	Right...
	bra Kbd_Skip



fl_ascii	dc	0
fl_white	dc	0

Kbd_ALT_W
*	Et vouala ! On passe de couleur en White&Black
	not fl_white
	bra Kbd_Skip

ALTP0s
	dc.b	"[1][Imprimante non prete|Hard Copy annul‚][ OK ]",0
	even

Kbd_ALT_P
*	Hard Copy sur l'imprimante (si elle est prete !)
	push #$11
	trap #1
	addq #2,sp
	tst d0
	bmi.s ALTP0
	form_alert #1,#ALTP0s
	bra Kbd_Skip

ALTP0
*	On envoie les caractŠres :
	move.l ascreen,a0
	moveq #25-1,d0			*25 lignes
ALTP1
	push.l a0
	push d0
	moveq #40-1,d0			*40 colonnes !
ALTP2
	clr d1
	move.b (a0)+,d1
	cmp.b #31,d1
	bhi.s altp2a
	moveq #32,d1
altp2a
	push.l a0
	push d0
	push d1
	push #$5
	trap #1
	addq #4,sp
	pop d0
	pop.l a0
	dbra d0,altp2

	push #13
	push #5
	trap #1
	addq #4,sp
	push #10
	push #5
	trap #1
	addq #4,sp

	pop d0
	pop.l a0
	lea 40(a0),a0			*Next Ligne !
	dbra d0,altp1

*	Fini !!!!
	bra Kbd_Skip


Kbd_ALT_S
	clr fl_ascii
	bra.s ALT_A0
Kbd_ALT_C
	move #-1,fl_ascii
	bra.s ALT_A0
Kbd_ALT_E
	move #-2,fl_ascii
	bra.s ALT_A0
Kbd_ALT_A
	move #1,fl_ascii
ALT_A0
*	On fais un FSEL_INPUT
	FSEL_INPUT #Path_Buf,#Fname_Buf
	tst int_out+2
	beq Kbd_Skip

*	On transfere path+name :
	bsr SET_FILENAME

*	On traite :
	move fl_ascii,d0
	bmi ALT_CE			*Charge ou ‚met...
	beq.s ALT_A1
	bsr TFR_Ascii
	bra.s Write_disk
ALT_A1
	bsr TFR_Videotex

Write_disk
*	Ouverture du fichier :
	push #0
	pea File_name
	push #$3c
	trap #1
	addq #8,sp

	tst d0
	bmi Disk_Error
	move d0,f_handle

*	Ecriture du fichier :
	lea DiskBuf,a0
	write a0,FileLen,f_handle
	tst d0
	bmi Disk_Error

*	Fermeture du fichier :
	close f_handle

*	et hop...
	bra Kbd_Skip


ALT_CE
*	Ouverture du fichier :
	open #0,File_Name
	tst d0
	bmi Disk_Error
	move d0,f_handle

*	Longueur du fichier ?
	lseek #2,f_handle,#0
	cmp.l #4000,d0
	blo.s ALT_CE0
	close f_handle
	move #-1,d0
	bra Disk_Error				*Trop long !

ALT_CE0
*	Sauvegarde Longueur fichier...
	move.l d0,FileLen

*	Repositionnement au d‚but :
	lseek #0,f_handle,#0

*	Lecture du fichier :
	lea DiskBuf,a0
	read a0,FileLen,f_handle
	tst d0
	bmi Disk_Error

*	Fermeture du fichier :
	close f_handle

*	Et maintenant on fout des 00 … la fin :
	lea DiskBuf,a0
	move.l FileLen,d0
	clr.b 0(a0,d0.l)
	clr.b 1(a0,d0.l)

*	et hop...
	move fl_ascii,d0
	cmp #-1,d0
	bne ALT_E			*Emission … 75bds...

	OUT_NITEL	DiskBuf
*	OUT_RS		DiskBuf
	move #-1,fl_review		*Remise … jours demand‚e !
	bra Kbd_Skip

ALT_E
*	Sur les deux....
	move #-1,fl_review		*Remise … jours demand‚e...

*	Sortie tranquillos ?
	tst fl_cx
	bne Emet

*	Pas support‚e pour l'instant !!!
	OUT_NITEL	DiskBuf
	OUT_RS		DiskBUf
	bra Kbd_Skip


Emet
*	Envoi ‡a … 75 caractŠres par seconde...
	lea DiskBuf,a0
Emet0
	clr d1
	move.b (a0)+,d1
	beq.s Emet9

	push.l a0
	push.l Timer200

	push d1
	push #4
	trap #1
	addq #4,sp

	pop.l d0
	Pop.l a0
Emet1
	move.l timer200,d1
	sub.l d0,d1
	cmp.l #28,d1
	bhi.s Emet0
	bra.s Emet1

Emet9
*	Fini !!!
	bra Kbd_Skip



Disk_Error
*	G‚neration d'une boite d'alerte :
	neg d0
	form_error d0
	rts


TFR_Videotex
*	Transfere simplement :
	lea PageBuf,a0
	move PagePtr,d0
	lea DiskBuf,a1
	move.b #12,(a1)+
tfrv0
	move.b (a0)+,(a1)+
	dbra d0,tfrv0
	clr.b (a1)+
	clr.b (a1)+

	clr.l d0
	move PagePtr,d0
	inc d0
	move.l d0,FileLen
	rts


TFR_Ascii
*	Transfert par ligne...
	move.l ascreen,a0
	lea DiskBuf,a1
	moveq #24,d0			*Nombre de lignes (-1)
tfra0
	moveq #39,d1			*Nombre de cars
tfra1
	move.b (a0)+,d2
	cmp.b #31,d2
	bhi.s tfra2
	moveq #32,d2
tfra2
	move.b d2,(a1)+
	dbra d1,tfra1
	move.b #$0d,(a1)+
	dbra d0,tfra0

	clr.b (a1)+
	clr.b (a1)+

	move.l #25*41,FileLen
	rts


*	routine : Path+Name >> File_Name
SET_FILENAME
	lea Path_buf,a0
	lea file_name,a1
ifn00
	move.b (a0)+,(a1)+
	bne.s ifn00
	dec a1

*	fin du path (*.x ou x.*) ???
	move.l a1,a2
ifn00a
	cmp.l #file_name,a2
	beq ifn00b
	move.b -(a2),d0
	cmp.b #'*',d0
	beq.s ifn10
	cmp.b #'\',d0
	beq.s ifn00b
	cmp.b #'?',d0
	beq.s ifn10
	bra.s ifn00a
ifn10
*	Ecrasement jusqu'au \ ou d‚but :
	cmp.l #file_name,a1
	beq.s ifn00b
	cmp.b #'\',-(a1)
	bne.s ifn10
	inc a1

ifn00b
	lea fname_buf(pc),a0
ifn01
	move.b (a0)+,(a1)+
	bne.s ifn01
*	fini !
	rts


*	data pour les noms de fichier :
Path_Buf	dc.b	"A:\*.*",0
		ds.b	128
		even
Fname_Buf	ds.b	32
		even
File_Name	ds.b	128
		even


Scan_table
*	table des codes :
	dc.b	$43,$5C
	dc.b	$44,$5D
	dc.b	$0E
	dc.b	$61
	dc.b	$62
	dc.b	$52
	dc.b	$4B
	dc.b	$48
	dc.b	$50
	dc.b	$47
	dc.b	$4d
	dc.b	$3b,$54
	dc.b	$3e,$57
	dc.b	$31
	dc.b	0
	even
Scan_Ptrs
*	Table des pointeurs correspondant aux chaines a envoyer :
	dc.l	ESC9g,ESC9g
	dc.l	Kbd_dcx,Kbd_dcx
	dc.l	Kbd_Correction
	dc.l	Kbd_Repetition
	dc.l	Kbd_Guide
	dc.l	Kbd_Tab
	dc.l	Kbd_Correction
	dc.l	Kbd_Retour
	dc.l	Kbd_Suite
	dc.l	kbd_Annulation
	dc.l	Kbd_TAB
	dc.l	Kbd_Connexion,Kbd_Connexion
	dc.l	Kbd_Sommaire,Kbd_Sommaire
	dc.l	Kbd_Numerote
	dc.l	0


ESC9g		dc.b	27,'9g',30,30,30,30,30,30,27,'9g',0
Kbd_TAB		dc.b	32,0
Kbd_Envoi	dc.b	$13,'A',0
Kbd_Retour	dc.b	$13,'B',0
Kbd_Repetition	dc.b	$13,'C',0
Kbd_Guide	dc.b	$13,'D',0
Kbd_Annulation	dc.b	$13,'E',0
Kbd_Sommaire	dc.b	$13,'F',0
Kbd_Correction	dc.b	$13,'G',0
Kbd_Suite	dc.b	$13,'H',0
Kbd_dcx		dc.b	$13,'I',0
Kbd_Connexion	dc.b	27,'9h',0
Kbd_Numerote	dc.b	27,'9g',27,$39,$53,27,$3b,$61,$5c,$53,0

Kbd_Accents
*	Les accentu‚s, au nombre de 8 :
	and #$00ff,d0
	lea ACC_TAB0,a0
	lea ACC_TAB1,a1
acc0
	cmp.b (a0)+,d0
	beq.s acc1
	addq #2,a1
	tst.b (a0)
	bne.s acc0
	rts

acc1
*	Trouv‚ : ‚mission...
	push.l a1
	push #$19
	push #4
	trap #1
	addq #4,sp

	move.l (sp),a0
	clr d0
	move.b (a0),d0
	push d0
	push #4
	trap #1
	addq #4,sp

	pop.l a0
	clr d0
	move.b 1(a0),d0
	beq.s acc2
	push d0
	push #4
	trap #1
	addq #4,sp
acc2
*	Fini !
	rts


ACC_TAB0
	DC.B	156
	dc.b	248
	dc.b	130,144
	dc.b	138
	dc.b	133,182
	dc.b	151
	dc.b	135,128
	dc.b	0,0
	even

ACC_TAB1
	dc.b	$23,0
	dc.b	$30,0
	dc.b	$42,$65,$42,$45
	dc.b	$41,$65
	dc.b	$41,$61,$41,$41
	dc.b	$41,$75
	dc.b	$4b,$63,$4b,$43
	dc.b	0,0,0,0,0,0
	even




Old200Hz	dc.l	0
PreCount	dc	1
Counter		dc.l	0
DeltaCount	dc	0
Timer200	dc.l	0
TimeCx		dc.l	0
Xcounter	dc	1
Blink_Count	dc.l	0
Blink_PreCount	dc	1
Mag_Timer	dc.l	-1
Mag_timer2	dc.l	0


New200hz
*	Et paf !
	push.l old200hz
	push sr

*	Toutes les 200Šme de s :
	inc.l Timer200

*	Xcounter		: 200->0
	tst Xcounter
	beq.s new0
	dec Xcounter
new0

*	DeltaCount
	cmp #300,DeltaCount
	beq.s new1
	inc DeltaCount
new1

*	PreCounter
	dec PreCount
	bne.s new2
	move #200,PreCount

*	Counter & ‚ventuellement TimeCx
	inc.l Counter
	tst fl_cx
	beq.s new2
	inc.l TimeCx
new2

*	D‚cr‚ment des compteurs pour le clignotement...
	dec Blink_Precount
	bne.s new3
	move #200,Blink_Precount		*100/100eme de s.
	inc.l Blink_Count
new3

*	Timer Record Magnetoscope...
	tst.l Mag_Timer
	bmi.s new4
	inc.l Mag_Timer
new4

*	Timer Play du magnetoscope...
	tst.l Mag_Timer2
	beq.s new5
	dec.l Mag_Timer2
new5

*	Juste retour simplex...
	rte



Try0s	dc.b	0,0,"-",0
Try1s	dc.b	0,0,"+",0
Try2s	dc.b	0,0,".",0
Try3s	dc.b	0,0,"*",0
	even



Mouse_Manager
*	A-t'il cliqu‚ sur la fenetre, hein ?!
	move mouse_state,d0
	eor #1,d0
	move d0,mouse_state
	beq Mouse_End

	move INT_OUT+12,MouseNbr

*	Maintenant, on compare les dimensions de la fenetre avec
*	Les coordonn‚es fournies :
	push int_out+2			*MouseX
	push int_out+4			*MouseY

*	On compare les tailles :
	wind_get w_handle,#11
	pop d1
	pop d0
	sub int_out+2,d0
	sub int_out+4,d1
	movem int_out+6,d2-d3
	cmp d2,d0
	bpl Mouse_End
	cmp d3,d1
	bpl Mouse_End

*	En cas de loupe :
	move fl_loupe,d7
	beq.s MMG0

*	Chgt de la coordonn‚e Y :
	sub #10,d1
	lsr #1,d1
	add #10,d1
	dec d7
	beq.s MMG0
	add #120,d1

MMG0
*	Coordonn‚es normalis‚es !

*	Prise du caractere correspondant !!!!
	ext.l d0
	divu #8,d0			*et paf !
	cmp #39,d0
	bhi Mouse_End
	ext.l d1
	divu #10,d1
;	dec d1
	tst d1
	bmi Mouse_End
	cmp #24,d1
	bhi Mouse_End

*	Transfert pour m‚moire !
	move d0,CellX
	move d1,CellY

MM11
*	Et transfert de la ligne :
	move.l ascreen,a0
	mulu #40,d1
	add d1,a0
	moveq #40-1,d0
	lea FindBuf,a1
	clr.b (a1)+
	clr.b (a1)+
MM00
	move.b (a0)+,(a1)+
	dbra d0,MM00
	clr.b (a1)+
	clr.b (a1)+

	lea FindBuf,a0
	move CellX,d0
*	C'est un chiffre ou quoi ???
	clr d1
MM13
	move.b 2(a0,d0.w),d1
	cmp.b #2,d1
	bne.s MM10
	inc Celly
	move Cellx,d0
	move Celly,d1
	cmp #24,d1
	bhi Mouse_Fin
*	on rempile !
	bra MM11

MM10
	cmp.b #1,d1
	bne.s MM12
	inc d0
	move d0,CellX
	bra.s MM13

MM12

	tst.b d1
	bne.s MMX
	dec d0
	move d0,Cellx
	move.b 2(a0,d0.w),d1
	bne.s MMX
	addq #2,d0
	move d0,Cellx
	move.b 2(a0,d0.w),d1
	beq Mouse_Fin				*Rat‚, dans le vide !

MMX
*	faudrait r‚cup‚rer une chaine ‚dulcor‚e ????
	lea 2(a0,d0.w),a0
	moveq #-1,d1			*et paf !
MM15
	move.b -(a0),d0
	cmp.b #1,d0
	beq.s MM15
	cmp.b #2,d0
	beq.s MM15
	inc d1
	cmp.b #32,d0
	bhs.s MM15

	inc a0
	lea FindXbuf,a1
	clr.b (a1)+
	clr.b (a1)+
MM16
	move.b (a0)+,d0
	beq.s MM17
	cmp.b #1,d0
	beq.s MM16
	cmp.b #2,d0
	beq.s MM16
	move.b d0,(a1)+
	bra.s MM16

MM17
*	Fini...
	clr.b (a1)+
	clr.b (a1)+
	lea FindXbuf,a0
	move d1,d0
	clr d1
	move.b 2(a0,d0.w),d1

	cmp.b #'0',d1
	bmi Mouse_MM17a				*Meme pas la peine d'en parler !
	cmp.b #'9',d1
	bls Mouse_Numeric			*Un nombre

Mouse_MM17a
*	Est-ce du texte ?
	cmp.b #'*',d1
	beq Mouse_Text
	cmp.b #'%',d1
	beq Mouse_Text
	cmp.b #'#',d1
	beq Mouse_Text

	cmp.b #'A',d1
	bmi Mouse_Fin
	cmp.b #'Z',d1
	bls Mouse_Text

	cmp.b #'a',d1
	bmi Mouse_Fin
	cmp.b #'z',d1
	bls Mouse_Text

Mouse_Fin
*	Hum ?!
	out_nitel TRY2s
	rts

Mouse_End
	out_nitel try3s
	rts

Mouse_Numeric
*	Prends les pr‚cedents :
	moveq #1,d2
	dec d0
MN00
	clr d1
	move.b 2(a0,d0.w),d1
	sub #'0',d1
	cmp #9,d1
	bhi.s MN01
	inc d2
	dec d0
	cmp #3,d2
	bne.s MN00
MN01
	inc d0
	lea 2(a0,d0.w),a0
	cmp #3,d2
	bhs.s MN03			*Pas plus de 3 !
MN02
*	Recherche en avan‡ant...
	clr d1
	move.b 0(a0,d2.w),d1
	sub #'0',d1
	cmp #9,d1
	bhi.s MN03
	inc d2
	cmp #3,d2
	bne.s MN02
MN03
	clr.b 0(a0,d2.w)

	OUT_RS (a0)
	OUT_NITEL TRY0S

*	Et la fin
	bra MOUSE_DCLICK


Mouse_Text
*	La c'est du text et on a l'air fin, hein ???
*	Prends les pr‚cedents :
	moveq #1,d2
	dec d0
MT00
	clr d1
	move.b 2(a0,d0.w),d1

	cmp.b #'%',d1
	beq.s MT00a
	cmp.b #'*',d1
	beq.s MT00a
	cmp.b #'#',d1
	beq.s MT00a

	cmp #'A',d1
	blo.s MT01
	cmp #'z',d1
	bhi.s MT01
MT00a
	inc d2
	dec d0
	cmp #8,d2
	bne.s MT00
MT01
	inc d0
	lea 2(a0,d0.w),a0

MT02
*	En avant now !
	clr d1
	move.b 0(a0,d2.w),d1

	cmp.b #'%',d1
	beq.s MT02a
	cmp.b #'#',d1
	beq.s MT02a
	cmp.b #'*',d1
	beq.s MT02a

	cmp #'A',d1
	blo.s MT03
	cmp #'z',d1
	bhi.s MT03
MT02a

	inc d2
	cmp #12,d2
	bne.s MT02
MT03
	clr.b 0(a0,d2.w)

	push.l a0
*	Voyons si ‡a correspond a qqchose de connu ???
	bsr Find_KEY
	pop.l a0

	OUT_RS (a0)
	OUT_NITEL TRY1S

*	A la souris, hop ! It's mice, isn't it ?
	bra Mouse_DClick


TAB_KEY
	dc.b	"REPETITION",0
	dc.b	"REPET",0
	dc.b	"SOMMAIRE",0
	dc.b	"SOMM",0
	dc.b	"GUIDE",0
	dc.b	"ANNULATION",0
	dc.b	"ANNUL",0
	dc.b	"CORRECTION",0
	dc.b	"CORRECT",0
	dc.b	"CORREC",0
	dc.b	"RETOUR",0
	dc.b	"SUITE",0
	dc.b	"ENVOI",0
	dc.b	0,0,0,0
	even

TAB_PTR
	dc.l	Kbd_Repetition
	dc.l	Kbd_Repetition
	dc.l	Kbd_Sommaire
	dc.l	Kbd_Sommaire
	dc.l	Kbd_Guide
	dc.l	Kbd_Annulation
	dc.l	Kbd_Annulation
	dc.l	Kbd_Correction
	dc.l	Kbd_Correction
	dc.l	Kbd_Correction
	dc.l	Kbd_Retour
	dc.l	Kbd_Suite
	dc.l	Kbd_Envoi
	dc.l	0,0,0,0


Find_Key
*	h‚h‚h‚
	lea TAB_KEY,a1
	clr d7
FC00
	move.l a1,a3
	move.l a0,a2
FC01
	tst.b (a3)
	beq.s FC10			*Egal ou a peu prŠs !
	clr d0
	move.b (a2)+,d0
	beq.s FC02
	and #31,d0
	add #$40,d0			*CaractŠre minuscule !
	cmp.b (a3)+,d0
	beq.s FC01

*	Diff‚rent...
FC02
	tst.b (a1)+
	bne.s FC02
	addq #4,d7				*Prochain !
	tst.b (a1)
	bne.s FC00

FC03
*	On quitte !
	rts


FC10
*	On remplace : Fire & Forget !
	lea TAB_PTR,a1
	move.l 0(a1,d7.w),d7
	beq.s FC03				*Quitte
	move.l d7,a1
FC11
	move.b (a1)+,(a0)+
	bne.s FC11
*	Et paf !
	rts



Mouse_DClick
*	Doucle click : on rajoute [ENVOI] derriŠre !!!!
	cmp #2,MouseNbr
	bne.s MD00

*	On emet un [ENVOI]
	OUT_RS Kbd_Envoi

MD00
*	C'est fini, on revient...hop !
	RTS


Store_Time
*	Time (d0,d1,d2) en (a0)+
	move d0,d3
	bsr Store_2dec
	move.b #$3a,(a0)+
	move d1,d3
	bsr Store_2dec
	move.b #$3a,(a0)+
	move d2,d3

Store_2dec
	ext.l d3
	divu #10,d3
	add #'0',d3
	move.b d3,(a0)+
	swap d3
	add #'0',d3
	move.b d3,(a0)+
	rts



Tableau_Flag	dc	0


View_Tableau
*	Flagged !
	move tableau_flag,d0
	bne View_t9
	move #-1,Tableau_Flag


*	Vectoriser le 200Hz
	super
	lea $45*4\w,a0
	move.l (a0),Old200Hz
	move.l #New200Hz,(a0)
	user


*	Afficher le tableau...
	lea Le_Tableau(pc),a0
	move.l vscreen(pc),a1
	add #10*800,a1			*Pointe sur le d‚but !
	moveq #7-1,d0
View_t0
	push d0
	pea 40(a0)
	pea 1600(a1)			*Next ligne a traiter !
	moveq #40-1,d0			*Nombre de caracteres...

View_t1
	clr d1
	move.b (a0)+,d1
	sub #'0',d1
	beq.s View_t2

*	Inversion complete du caractere !
	eor.b #$3C,(a1)
	eor.b #$7E,80(a1)
	not.b 160(a1)
	not.b 240(a1)
	not.b 320(a1)
	not.b 400(a1)
	not.b 480(a1)
	eor.b #$7E,560(a1)
	eor.b #$3C,640(a1)

View_t2
	inc a1
	dbra d0,View_t1
	pop.l a1
	pop.l a0
	pop d0
	dbra d0,View_t0

View_t9
*	Right !
	rts


	SECTION	DATA


V_Bauds		dc	7
V_Parite	dc	%11
V_Bits		dc	7
V_Actif		dc	-1		*Drapeau actif...
V_Raw		dc	0		*Variable de travail...


* all C strings must end in a null
windowname	dc.b	' Nitel by Phil v1.1',0
Demar0s		dc.b	27,$45,13,10
		dc.b	"Emulateur minitel (c) 1989 Sictel.",13,10,0
		even

*	Les chaines !
Nom_Appli	dc.b	"  Emulateur Nitel ",0
	even
Menu_Id		dc	0


ClrWin1
	dc.b 12,$1f,'00',27,$54," Emulateur minitel (c) 1989 Sictel",$18,10
	dc.b $1f,'01',$14
	dc.b 0

ClrWIn3
	dc.b 27,$3a,$65,$5b
	dc.b 27,$3a,$6a,$43
	dc.b 0,0
	even



*	tableaux d'affichages :
str00	dc.b	"Vitesse (baud)  Parit‚  bits R‚ception: ",0
str01	dc.b	"- 1200+",0
str02	dc.b	"PAIRE",0
str03	dc.b	"7",0
str04	dc.b	"ACTIVE",0
	even


str02x	dc.l	0
*	Les diff‚rentes parit‚es :
str02a	dc.b	" NON ",0
str02b	dc.b	" IMP.",0
str02c	dc.b	"PAIRE",0
	even


str04a	dc.b	"ARRETE",0
str04b	dc.b	"ACTIVE",0
	even


*	Ecran Virtuel et Ascii..
ascreen	dc.l	0
vscreen	dc.l	0
vscr2	dc.l	0
ScrPtr	dc.l	0		*Pointeur ecran virtuel courant


La_Page
*	La page d'accueil ...
	dc.b	12
	dc.b	$1f,"01 ",$12,'V',27,$45,'`',$12,'O'
	dc.b	$1f,"02 ",14,27,$46,"/// / /// /// /// _   ",15,'`',$12,'O'
	dc.b	$1f,"03 ",14,27,$46,"o|t _ _    _  _// _   ",15,'`',$12,'O'
	dc.b	$1f,"04 ",14,27,$46,"||? _ o||  o4 o|| o|4 ",15,'`',$12,'O'
	dc.b	$1f,"05 ",$12,'V',27,$46,"`",$12,"O"

	dc.b	$1f,"07  Serveur, Informatique & Communication"
	dc.b	$1f,"08            B.P.  68"
	dc.b	$1f,"09      94703 Maisons-Alfort Cedex"

	dc.b	$1f,"12F1:Connexion       ALT-N:Num‚rotation"
	dc.b	$1f,"13F2:Loupe           ALT-S:Sauver en VDTX"
	dc.b	$1f,"14F3:                ALT-A:Sauver en Ascii"
	dc.b	$1f,"15F4:Sommaire        ALT-C:Charger Page"
	dc.b	$1f,"16F5:                ALT-E:Emettre Page"
	dc.b	$1f,"17F6:Minitel OFF     ALT-W:Couleur <-> N&B"
	dc.b	$1f,"18F7:Minitel ON      ALT-P:Impression Text"
	dc.b	$1f,"19F8:                ALT-D:Espace Disque"
	dc.b	$1f,"20F9:Deconnecte      ALT-M:Magn‚toscope..."
	dc.b	$1f,"21F0:Fin             ALT-K:Keyboard K7"
	dc.b	$1f,"22                   ALT-T:Telechargement"
	dc.b	0,0,0,0,0
	even


Le_Tableau
	dc.b	"0111111100001111110001100001100011111100"
	dc.b	"0110000110001100000001110011100110000110"
	dc.b	"0110000110001100000001101101100110000110"
	dc.b	"0110000110001111000001101101100110000110"
	dc.b	"0110000110001100000001100001100110000110"
	dc.b	"0110000110001100000001100001100110000110"
	dc.b	"0111111100001111110001100001100011111100"
	even

* global constants
	SECTION	BSS

* these have to remain together
xstart	ds.w 1
ystart	ds.w 1
xwidth	ds.w 1
ywidth	ds.w 1

w_handle	ds.w 1
ws_handle	ds.w 1
ap_id		ds.w 1
messagebuf	ds.b 32

MouseX		ds.w	1
MouseY		ds.w	1
MouseNbr	ds.w	1
CellX		ds.w	1
CellY		ds.w	1
FindBuf		ds.b	64		*Recherche sur cliquage !
FindXBuf	ds.b	64		*Recherche ‚dulcor‚e !

PagePtr		ds.l	1
FileLen		ds.l	1
f_handle	ds.l	1
Mag_Len		ds.w	1
Mag_Ptr		ds.l	1

PageBuf		ds.b	4100
DiskBuf		ds.b	4100		*Pour l'‚criture !
RS_XBuf		ds.b	4100
Mag_Buf		ds.b	8200		*Pour les IO g‚n‚rales...avec recouvrement !

	ds.l	100			stack space
mystack	ds.w	1			(stacks go backwards)


* if not linking then include the run-times

	IFEQ	__LK
	include	aeslib.s
	include	vdilib.s
	ENDC

