;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Client.asm
; 使用 UDP 协议的聊天室例子程序 —— 客户端
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff Client.asm
; rc Client.rc
; Link /subsystem:windows Client.obj Client.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none   ; case sensitive
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	Include 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		wsock32.inc
includelib	wsock32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	equ 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DLG_MAIN	equ	2000
IDC_SERVER	equ	2001
IDC_INFO	equ	2002
IDC_TEXT	equ	2003
WM_SOCKET       equ	WM_USER + 100
UDP_PORT	equ	9999
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hWinMain	dd	?
hSocket		dd	?
szReadBuffer	db	32768 dup (?)
		.const
szIP		db	'127.0.0.1',0
szErrIP		db	'无效的服务器IP地址!',0
dwReturn	dd	-1
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 接收到UDP数据包时显示到edit控件中，然后回复一个 －1
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
; 将输入框中的文字发送出去
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
; 初始化 Socket
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
;	主窗口程序
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
; 程序开始
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		invoke	GetModuleHandle,NULL
		invoke	DialogBoxParam,eax,DLG_MAIN,NULL,offset _ProcDlgMain,0
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start
