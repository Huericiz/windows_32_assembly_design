;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Server.asm
; 使用 TCP 协议的聊天室例子程序 —— 服务器端
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff Server.asm
; rc Server.rc
; Link /subsystem:windows Server.obj Server.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none   ; case sensitive
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		wsock32.inc
includelib	wsock32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; equ 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DLG_MAIN	equ	2000
IDC_INFO	equ	2001
IDC_COUNT	equ	2002
WM_SOCKET       equ	WM_USER + 100
TCP_PORT	equ	9999
MAX_SOCKET	equ	100	;聊天室最大容量
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hWinMain	dd	?
hSocket		dd	?
dwCount		dd	?
szReadBuffer	db	32768 dup (?)
szBuffer	db	32768 dup (?)
stTable		dd	MAX_SOCKET dup (?)
		.const
szErrBind	db	'无法绑定到TCP端口9999，请检查是否有其它程序在使用!',0
szFormat	db	'【客户端#%08x】- %s',0dh,0ah,0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 在客户端列表中加上一个 socket
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_AddClient	proc	_hSocket

		invoke	WSAAsyncSelect,_hSocket,hWinMain,WM_SOCKET,FD_READ or FD_CLOSE
		xor	ebx,ebx
		mov	esi,offset stTable
		.while	ebx <	MAX_SOCKET
			.if	! dword ptr [esi]
				push	_hSocket
				pop	[esi]
				inc	dwCount
				invoke	SetDlgItemInt,hWinMain,IDC_COUNT,dwCount,FALSE
				ret
			.endif
			inc	ebx
			add	esi,4
		.endw
		invoke	closesocket,_hSocket
		ret

_AddClient	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 从客户端列表中去掉一个 socket
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RemoveClient	proc	_hSocket

		xor	ebx,ebx
		mov	esi,offset stTable
		mov	edi,_hSocket
		.while	ebx <	MAX_SOCKET
			.if	[esi] == edi
				invoke	closesocket,[esi]
				mov	dword ptr [esi],0
				dec	dwCount
				invoke	SetDlgItemInt,hWinMain,IDC_COUNT,dwCount,FALSE
				ret
			.endif
			inc	ebx
			add	esi,4
		.endw
		ret

_RemoveClient	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 处理接收到的TCP包
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc	_hSocket
		local	@dwRecv

		invoke	RtlZeroMemory,addr szReadBuffer,sizeof szReadBuffer
		invoke	recv,_hSocket,addr szReadBuffer,sizeof szReadBuffer,NULL
		.if	eax !=	SOCKET_ERROR
			mov	@dwRecv,eax
			invoke	wsprintf,addr szBuffer,addr szFormat,\
				_hSocket,addr szReadBuffer
;********************************************************************
; 按照客户端列表逐一发送
;********************************************************************
			invoke	GetDlgItem,hWinMain,IDC_INFO
			mov	ebx,eax
			invoke	GetWindowTextLength,ebx
			invoke	SendMessage,ebx,EM_SETSEL,eax,eax
			invoke	SendMessage,ebx,EM_REPLACESEL,FALSE,addr szBuffer
			mov	esi,offset stTable
			xor	ebx,ebx
			.while	ebx <	MAX_SOCKET
				mov	edi,[esi]
				.if	edi
					invoke	lstrlen,addr szBuffer
					invoke	send,edi,addr szBuffer,eax,0
				.endif
				add	esi,4
				inc	ebx
			.endw
		.endif
		ret

_RecvData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 初始化 Socket，绑定到服务TCP端口并监听
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Init		proc
		local	@stWsa:WSADATA
		local	@stSin:sockaddr_in

		invoke	WSAStartup,101h,addr @stWsa
		invoke	socket,AF_INET,SOCK_STREAM,0
		mov	hSocket,eax
		invoke	WSAAsyncSelect,hSocket,hWinMain,WM_SOCKET,FD_ACCEPT

		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	htons,TCP_PORT
		mov	@stSin.sin_port,ax
		mov	@stSin.sin_family,AF_INET
		mov	@stSin.sin_addr,INADDR_ANY
		invoke	bind,hSocket,addr @stSin,sizeof @stSin
		.if	eax ==	SOCKET_ERROR
			invoke	MessageBox,hWinMain,addr szErrBind,NULL,\
				MB_OK or MB_ICONWARNING
			invoke	SendMessage,hWinMain,WM_CLOSE,0,0
		.else
			invoke	listen,hSocket,5
		.endif
		ret

_Init		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 主窗口程序
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam

		mov	eax,wMsg
		.if	eax ==	WM_SOCKET
			mov	eax,lParam
			.if	ax ==	FD_ACCEPT
				invoke	accept,wParam,0,0
				invoke	_AddClient,eax
			.elseif	ax ==	FD_READ
				invoke	_RecvData,wParam
			.elseif	ax ==	FD_CLOSE
				invoke	_RemoveClient,wParam
			.endif
;********************************************************************
; 退出时关闭全部连接
;********************************************************************
		.elseif	eax ==	WM_CLOSE
			invoke	closesocket,hSocket
			xor	ebx,ebx
			mov	esi,offset stTable
			cld
			.while	ebx <	MAX_SOCKET
				lodsd
				.if	eax
					invoke	closesocket,eax
				.endif
				inc	ebx
			.endw
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
