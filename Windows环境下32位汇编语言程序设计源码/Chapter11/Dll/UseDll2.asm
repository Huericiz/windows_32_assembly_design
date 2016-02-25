;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by ���Ʊ�, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; UseDll2.asm
; �Ա� Counter.dll �еĺ�����ʹ�÷�����ʾ����
; �ö�̬װ�� dll �ļ��ķ�ʽ���� dll �еĺ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ʹ�� nmake ������������б��������:
; ml /c /coff UseDll2.asm
; rc UseDll.rc
; Link  /subsystem:windows UseDll2.obj UseDll.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include �ļ�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Equ ��ֵ����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ICO_MAIN	equ	1000
DLG_MAIN	equ	1000
IDC_COUNTER	equ	1001
IDC_INC		equ	1002
IDC_DEC		equ	1003

_PROCVAR2	typedef proto :dword,:dword
PROCVAR2	typedef ptr _PROCVAR2
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?

hDllInstance	dd	?
lpIncCount	PROCVAR2	?
lpDecCount	PROCVAR2	?

		.const
szError		db	'Counter.dll �ļ���ʧ��װ��ʧ�ܣ����������޷�ʵ��',0
szDll		db	'Counter.dll',0
szIncCount	db	'_IncCount',0
szDecCount	db	'_DecCount',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam

		mov	eax,wMsg
;********************************************************************
		.if	eax ==	WM_CLOSE
			.if	hDllInstance
				invoke	FreeLibrary,hDllInstance
			.endif
			invoke	EndDialog,hWnd,NULL
;********************************************************************
		.elseif	eax ==	WM_INITDIALOG
			invoke	LoadLibrary,addr szDll
			.if	eax
				mov	hDllInstance,eax
				invoke	GetProcAddress,hDllInstance,addr szIncCount
				mov	lpIncCount,eax
				invoke	GetProcAddress,hDllInstance,addr szDecCount
				mov	lpDecCount,eax
			.else
				invoke	MessageBox,hWnd,addr szError,NULL,MB_OK or MB_ICONWARNING
				invoke	GetDlgItem,hWnd,IDC_INC
				invoke	EnableWindow,eax,FALSE
				invoke	GetDlgItem,hWnd,IDC_DEC
				invoke	EnableWindow,eax,FALSE
			.endif
;********************************************************************
		.elseif	eax ==	WM_COMMAND
			mov	eax,wParam
			.if	ax ==	IDC_INC
				.if	lpIncCount
					invoke	lpIncCount,hWnd,IDC_COUNTER
				.endif
			.elseif	ax ==	IDC_DEC
				.if	lpDecCount
					invoke	lpDecCount,hWnd,IDC_COUNTER
				.endif
			.endif
		.else
			mov	eax,FALSE
			ret
		.endif
		mov	eax,TRUE
		ret

_ProcDlgMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		invoke	GetModuleHandle,NULL
		invoke	DialogBoxParam,eax,DLG_MAIN,NULL,offset _ProcDlgMain,NULL
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start
