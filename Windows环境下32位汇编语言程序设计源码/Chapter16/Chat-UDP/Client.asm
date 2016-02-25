;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by ���Ʊ�, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Client.asm
; ʹ�� UDP Э������������ӳ��� ���� �ͻ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ʹ�� nmake ������������б��������:
; ml /c /coff Client.asm
; rc Client.rc
; Link /subsystem:windows Client.obj Client.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none   ; case sensitive
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	Include ����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		wsock32.inc
includelib	wsock32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	equ ����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DLG_MAIN	equ	2000
IDC_SERVER	equ	2001
IDC_INFO	equ	2002
IDC_TEXT	equ	2003
WM_SOCKET       equ	WM_USER + 100
UDP_PORT	equ	9999
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hWinMain	dd	?
hSocket		dd	?
szReadBuffer	db	32768 dup (?)
		.const
szIP		db	'127.0.0.1',0
szErrIP		db	'��Ч�ķ�����IP��ַ!',0
dwReturn	dd	-1
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���յ�UDP���ݰ�ʱ��ʾ��edit�ؼ��У�Ȼ��ظ�һ�� ��1
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc	_hSocket
		local	@dwRecv,@dwSize
		local	@stSin:sockaddr_in

		mov	@dwSize,sizeof @stSin
		invoke	RtlZeroMemory,addr szReadBuffer,sizeof szReadBuffer
		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	recvfrom,_hSocket,addr szReadBuffer,sizeof szReadBuffer,\
			0,addr @stSin,addr @dwSize
		.if	eax !=	SOCKET_ERROR
			invoke	sendto,hSocket,addr dwReturn,4,\
				0,addr @stSin,sizeof sockaddr_in
			.if	eax ==	SOCKET_ERROR
				invoke	WSAGetLastError
				.if	eax == WSAEWOULDBLOCK
					invoke	GetDlgItem,hWinMain,IDOK
					invoke	EnableWindow,eax,FALSE
				.endif
			.endif
			invoke	GetDlgItem,hWinMain,IDC_INFO
			mov	ebx,eax
			invoke	GetWindowTextLength,ebx
			invoke	SendMessage,ebx,EM_SETSEL,eax,eax
			invoke	SendMessage,ebx,EM_REPLACESEL,FALSE,addr szReadBuffer
		.endif
		ret

_RecvData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ��������е����ַ��ͳ�ȥ
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendData	proc
		local	@szBuffer[1024]:byte
		local	@stSin:sockaddr_in

		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	GetDlgItemText,hWinMain,IDC_SERVER,addr @szBuffer,sizeof @szBuffer
		invoke	inet_addr,addr @szBuffer
		.if	eax ==	INADDR_NONE
			invoke	MessageBox,hWinMain,addr szErrIP,NULL,\
				MB_OK or MB_ICONWARNING
			jmp	@F
		.endif
		mov	@stSin.sin_addr,eax
		mov	@stSin.sin_family,AF_INET
		invoke	htons,UDP_PORT
		mov	@stSin.sin_port,ax
		invoke	GetDlgItemText,hWinMain,IDC_TEXT,addr @szBuffer,sizeof @szBuffer
		invoke	lstrlen,addr @szBuffer
		.if	eax
			mov	ecx,eax
			invoke	sendto,hSocket,addr @szBuffer,ecx,\
				0,addr @stSin,sizeof sockaddr_in
			.if	eax ==	SOCKET_ERROR
				invoke	WSAGetLastError
				.if	eax == WSAEWOULDBLOCK
					invoke	GetDlgItem,hWinMain,IDOK
					invoke	EnableWindow,eax,FALSE
				.endif
			.endif
		.endif
		@@:
		invoke	SetDlgItemText,hWinMain,IDC_TEXT,NULL
		ret

_SendData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ��ʼ�� Socket
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Init		proc
		local	@stWsa:WSADATA

		invoke	SetDlgItemText,hWinMain,IDC_SERVER,addr szIP
		invoke	WSAStartup,101h,addr @stWsa
		invoke	socket,AF_INET,SOCK_DGRAM,0
		mov	hSocket,eax
		invoke	WSAAsyncSelect,hSocket,hWinMain,WM_SOCKET,FD_READ or FD_WRITE
		ret

_Init		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	�����ڳ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam

		mov	eax,wMsg
;********************************************************************
		.if	eax ==	WM_SOCKET
			mov	eax,lParam
			.if	ax ==	FD_READ
				invoke	_RecvData,wParam
			.elseif	ax ==	FD_WRITE
				invoke	GetDlgItem,hWnd,IDOK
				invoke	EnableWindow,eax,TRUE
			.endif
;********************************************************************
		.elseif	eax ==	WM_COMMAND
			mov	eax,wParam
			.if	ax ==	IDOK
				invoke	_SendData
			.endif
;********************************************************************
		.elseif	eax ==	WM_CLOSE
			invoke	closesocket,hSocket
			invoke	WSACleanup
			invoke	EndDialog,hWinMain,NULL
;********************************************************************
		.elseif	eax ==	WM_INITDIALOG
			push	hWnd
			pop	hWinMain
			call	_Init
;********************************************************************
		.else
			mov	eax,FALSE
			ret
		.endif
		mov	eax,TRUE
		ret

_ProcDlgMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����ʼ
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		invoke	GetModuleHandle,NULL
		invoke	DialogBoxParam,eax,DLG_MAIN,NULL,offset _ProcDlgMain,0
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start
