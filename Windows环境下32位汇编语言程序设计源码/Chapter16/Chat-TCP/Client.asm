;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by ���Ʊ�, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Client.asm
; ʹ�� TCP Э������������ӳ��� ���� �ͻ���
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
IDC_CONNECT	equ	2002
IDC_INFO	equ	2003
IDC_TEXT	equ	2004
WM_SOCKET       equ	WM_USER + 100
TCP_PORT	equ	9999
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hWinMain	dd	?
hSocket		dd	?
hWinConnect	dd	?
hWinOK		dd	?
hWinText	dd	?
hWinServer	dd	?
hWinInfo	dd	?
szReadBuffer	db	32768 dup (?)
		.const
szIP		db	'127.0.0.1',0
szConnect	db	'����(&C)',0
szDisConnect	db	'�Ͽ�(&D)',0
szErrIP		db	'��Ч�ķ�����IP��ַ!',0
szErrSocket	db	'����Socket����!',0
szErrConnect	db	'�޷����ӵ�������!',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; TCP/IP �������ӵ��õ��߳�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Connect	proc	uses ebx esi edi _lParam
		local	@szBuffer[256]:byte
		local	@stSin:sockaddr_in
;********************************************************************
; ת��IP��ַ������socket
;********************************************************************
		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	GetDlgItemText,hWinMain,IDC_SERVER,addr @szBuffer,sizeof @szBuffer
		invoke	inet_addr,addr @szBuffer
		.if	eax ==	INADDR_NONE
			mov	ebx,offset szErrIP
			jmp	_Error
		.endif
		mov	@stSin.sin_addr,eax
		mov	@stSin.sin_family,AF_INET
		invoke	htons,TCP_PORT
		mov	@stSin.sin_port,ax

		invoke	socket,AF_INET,SOCK_STREAM,0
		.if	eax ==	INVALID_SOCKET
			mov	ebx,offset szErrSocket
			jmp	_Error
		.endif
		mov	hSocket,eax
;********************************************************************
; ���ӵ�������
;********************************************************************
		invoke	EnableWindow,hWinConnect,FALSE
		invoke	EnableWindow,hWinServer,FALSE
		invoke	WSAAsyncSelect,hSocket,hWinMain,WM_SOCKET,FD_CONNECT or FD_READ or FD_CLOSE or FD_WRITE
		invoke	connect,hSocket,addr @stSin,sizeof @stSin
		.if	eax ==	SOCKET_ERROR
			invoke	WSAGetLastError
			.if eax != WSAEWOULDBLOCK
				call	_DisConnect
				mov	ebx,offset szErrConnect
				jmp	_Error
			.endif
		.endif
		ret
_Error:
		invoke	MessageBox,hWinMain,ebx,NULL,\
			MB_OK or MB_ICONWARNING
		ret

_Connect	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �Ͽ�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_DisConnect	proc

		invoke	closesocket,hSocket
		mov	hSocket,0
		invoke	SetWindowText,hWinConnect,addr szConnect
		invoke	EnableWindow,hWinServer,TRUE
		invoke	EnableWindow,hWinConnect,TRUE
		invoke	EnableWindow,hWinText,FALSE
		invoke	EnableWindow,hWinOK,FALSE
		ret

_DisConnect	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����TCP���ݰ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc	_hSocket

		invoke	RtlZeroMemory,addr szReadBuffer,sizeof szReadBuffer
		invoke	recv,_hSocket,addr szReadBuffer,sizeof szReadBuffer,NULL
		.if	eax !=	SOCKET_ERROR
			invoke	GetWindowTextLength,hWinInfo
			invoke	SendMessage,hWinInfo,EM_SETSEL,eax,eax
			invoke	SendMessage,hWinInfo,EM_REPLACESEL,FALSE,addr szReadBuffer
		.endif
		ret

_RecvData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �������������
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendData	proc
		local	@szBuffer[1024]:byte

		invoke	GetDlgItemText,hWinMain,IDC_TEXT,addr @szBuffer,sizeof @szBuffer
		invoke	lstrlen,addr @szBuffer
		.if	eax
			invoke	send,hSocket,addr @szBuffer,eax,0
			.if	eax ==	SOCKET_ERROR
				invoke	WSAGetLastError
				.if	eax == WSAEWOULDBLOCK
					invoke	EnableWindow,hWinOK,FALSE
				.endif
			.endif
		.endif
		invoke	SetDlgItemText,hWinMain,IDC_TEXT,NULL
		ret

_SendData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �����ڳ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam
		local	@stWsa:WSADATA,@dwThreadID

		mov	eax,wMsg
		.if	eax ==	WM_SOCKET
;********************************************************************
; ���� Socket ��Ϣ
;********************************************************************
			mov	eax,lParam
			.if	ax ==	FD_READ
				invoke	_RecvData,wParam
			.elseif	ax ==	FD_WRITE
				invoke	EnableWindow,hWinOK,TRUE
			.elseif	ax ==	FD_CONNECT
				shr	eax,16
				.if	ax ==	NULL
					invoke	SetWindowText,hWinConnect,addr szDisConnect
					invoke	EnableWindow,hWinConnect,TRUE
					invoke	EnableWindow,hWinServer,FALSE
					invoke	EnableWindow,hWinText,TRUE
					invoke	EnableWindow,hWinOK,TRUE
					invoke	SetFocus,hWinText
				.else
					invoke	_DisConnect
					invoke	MessageBox,hWinMain,offset szErrConnect,NULL,\
						MB_OK or MB_ICONWARNING
				.endif
			.elseif	ax ==	FD_CLOSE
				call	_DisConnect
			.endif
;********************************************************************
		.elseif	eax ==	WM_COMMAND
			mov	eax,wParam
			.if	ax ==	IDOK
				invoke	_SendData
			.elseif	ax ==	IDC_CONNECT
				.if	hSocket
					invoke	_DisConnect
				.else
					invoke	CreateThread,NULL,0,offset _Connect,NULL,\
						NULL,addr @dwThreadID
					invoke	CloseHandle,eax
				.endif
			.endif
;********************************************************************
		.elseif	eax ==	WM_CLOSE
			invoke	_DisConnect
			invoke	WSACleanup
			invoke	EndDialog,hWinMain,NULL
;********************************************************************
		.elseif	eax ==	WM_INITDIALOG
			push	hWnd
			pop	hWinMain
			invoke	GetDlgItem,hWnd,IDC_SERVER
			mov	hWinServer,eax
			invoke	GetDlgItem,hWnd,IDOK
			mov	hWinOK,eax
			invoke	GetDlgItem,hWnd,IDC_TEXT
			mov	hWinText,eax
			invoke	GetDlgItem,hWnd,IDC_CONNECT
			mov	hWinConnect,eax
			invoke	GetDlgItem,hWnd,IDC_INFO
			mov	hWinInfo,eax
			invoke	SetWindowText,hWinServer,addr szIP
			invoke	WSAStartup,101h,addr @stWsa
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
