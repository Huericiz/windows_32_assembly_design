;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Ping.asm
; 类似于 Windows 自带的 Ping.exe 程序，用 ICMP 协议实现 Ping 的功能
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff Ping.asm
; Link /SUBSYSTEM:CONSOLE Ping.obj
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		kernel32.inc
includelib	kernel32.lib
include		user32.inc
includelib	user32.lib
include		wsock32.inc
includelib	wsock32.lib
PACKET_SIZE	equ	32		;缺省包尺寸为 32 字节
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
szHostName	db	100 dup (?)
szBuffer	db	1024 dup (?)
szBigBuffer	db	65536 dup (?)	;接收 ICMP_REPLY 的大缓冲区
stWsa		WSADATA	<>
;********************************************************************
; 标志及命令行参数
;********************************************************************
dwOption	dd	?
F_ABORT		equ	0001h		;按了 Ctrl-C 终止

		.data
szHelp		db	'Usage: ping hostname',0dh,0ah,0ah
		db	'example:',0dh,0ah
		db	'  ping 127.0.0.1',0dh,0ah
		db	'  ping www.desthost.com',0dh,0ah,0
szErrHost	db	'Unknown host [%s]',0dh,0ah,0
szErrSocket	db	'Socket error.',0dh,0ah,0
szErrTimeout	db	'Request timed out.',0dh,0ah,0
szErrUnreach	db	'Destination host unreachable.',0dh,0ah,0
szHostOneIP	db	'The IP address of [%s] is %s',0dh,0ah,0
szPingOneIP	db	'Ping %s with 32 bytes of data:',0dh,0ah,0ah,0
szHostMoreIP	db	'The host [%s] has %d IP addresses:',0dh,0ah,0
szPingMoreIP	db	0dh,0ah,'Ping first IP %s with 32 bytes of data:',0dh,0ah,0ah,0
szSpar		db	' / ',0
szReply		db	'Reply from %s: bytes=%d time=%dms TTL=%d',0dh,0ah,0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
include		_CmdLine.asm
include		_Console.asm
include		_CheckSum.asm
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_HostnameToIP	proc	_lpszHostName
		local	@szBuffer[256]:byte
		local	@dwIP

		invoke	inet_addr,_lpszHostName
		.if	eax !=	INADDR_NONE
;********************************************************************
; 输入的是IP地址
;********************************************************************
			mov	@dwIP,eax
			invoke	inet_ntoa,eax
			invoke	wsprintf,addr szBuffer,addr szPingOneIP,eax
		.else
;********************************************************************
; 输入的是主机名称
;********************************************************************
			invoke	gethostbyname,_lpszHostName
			.if	eax
				xor	edi,edi		;用edi做计数器
				mov	eax,[eax+hostent.h_list]
				.while	dword ptr [eax]
					mov	ebx,[eax]
					push	[ebx]
					inc	edi
					add	eax,4
				.endw
				pop	eax
				mov	@dwIP,eax
				invoke	inet_ntoa,eax
				mov	ebx,eax
				.if	edi ==	1	;主机对应一个IP地址
					invoke	wsprintf,addr szBuffer,addr szHostOneIP,_lpszHostName,ebx
					invoke	wsprintf,addr @szBuffer,addr szPingOneIP,ebx
				.else			;主机对应多个IP地址
					invoke	wsprintf,addr szBuffer,addr szHostMoreIP,_lpszHostName,edi
					invoke	lstrcat,addr szBuffer,ebx
					invoke	wsprintf,addr @szBuffer,addr szPingMoreIP,ebx
					.while	edi > 1
						invoke	lstrcat,addr szBuffer,addr szSpar
						pop	eax
						invoke	inet_ntoa,eax
						invoke	lstrcat,addr szBuffer,eax
						dec	edi
					.endw
				.endif
				invoke	lstrcat,addr szBuffer,addr @szBuffer
			.else
				invoke	wsprintf,addr szBuffer,addr szErrHost,addr szHostName
				invoke	_ConsolePrint,addr szBuffer
				xor	eax,eax
				ret
			.endif
		.endif
		invoke	_ConsolePrint,addr szBuffer
		mov	eax,@dwIP
		ret

_HostnameToIP	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Ping 主程序
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Ping		proc	_dwIP
		local	@szBuffer[256]:byte
		local	@stDest:sockaddr_in
		local	@stFrom:sockaddr_in
		local	@hSocket,@dwSize
		local	@stFdSet:fd_set
		local	@stTimeval:timeval
		local	@dwID:word,@dwSeq:word

		pushad
		mov	@stDest.sin_port,0
		mov	@stDest.sin_family,AF_INET
		push	_dwIP
		pop	@stDest.sin_addr
;********************************************************************
; 初始化一个 socket 发送 ICMP 的 RAW 数据
;********************************************************************
		invoke	socket,AF_INET,SOCK_RAW,IPPROTO_ICMP
		.if	eax ==	INVALID_SOCKET
			invoke	_ConsolePrint,addr szErrSocket
			jmp	_Ping_Ret
		.endif
		mov	@hSocket,eax
;********************************************************************
; 循环 Ping
;********************************************************************
		xor	ebx,ebx
		mov	@dwID,1
		mov	@dwSeq,1
		.while	TRUE
			.break	.if (dwOption & F_ABORT) || (ebx >= 4)
			inc	ebx
			assume	esi:ptr icmp_hdr
			mov	esi,offset szBigBuffer
			invoke	RtlZeroMemory,esi,sizeof szBigBuffer
;********************************************************************
; 构造 Echo Request 数据包
;********************************************************************
			mov	ax,@dwID
			mov	[esi].icmp_id,ax
			mov	ax,@dwSeq
			mov	[esi].icmp_seq,ax
			mov	[esi].icmp_type,ICMP_ECHOREQ	;构造 ICMP_ECHO_REQ 数据包

			invoke	GetTickCount
			mov	dword ptr [esi].icmp_data,eax	;将当前时间作为数据
			mov	ecx,PACKET_SIZE
			add	ecx,sizeof icmp_hdr-1
			invoke	_CalcCheckSum,addr szBigBuffer,ecx
			mov	[esi].icmp_cksum,ax
;********************************************************************
; 发送 Echo Request 数据包
;********************************************************************
			invoke	sendto,@hSocket,addr szBigBuffer,ecx,\
				 0,addr @stDest,sizeof sockaddr_in
			.if	eax == SOCKET_ERROR
				invoke	_ConsolePrint,addr szErrUnreach
				.continue
			.endif
			assume	esi:nothing
;********************************************************************
; 等待回复
;********************************************************************
			@@:
			mov	@stFdSet.fd_count,1
			push	@hSocket
			pop	@stFdSet.fd_array
			mov	@stTimeval.tv_sec,0
			mov	@stTimeval.tv_usec,1000000	;超时时间1秒

			invoke	select,0,addr @stFdSet,NULL,NULL,addr @stTimeval
			.if	eax == SOCKET_ERROR
				invoke	_ConsolePrint,addr szErrSocket
				.continue
			.endif
			.if	eax
;********************************************************************
; 接收返回数据包
;********************************************************************
				mov	@dwSize,sizeof @stFrom
				invoke	recvfrom,@hSocket,addr szBigBuffer,sizeof szBigBuffer,\
					0,addr @stFrom,addr @dwSize
				.if	eax == SOCKET_ERROR
					invoke	_ConsolePrint,addr szErrSocket
				.else
					mov	eax,@stFrom.sin_addr
					.if	eax !=	@stDest.sin_addr
						jmp	@B
					.endif
					mov	bx,word ptr szBigBuffer+sizeof ip_hdr+icmp_hdr.icmp_id
					mov	cx,word ptr szBigBuffer+sizeof ip_hdr+icmp_hdr.icmp_seq
					.if	bx != @dwID || cx != @dwSeq
						jmp	@B
					.endif
;********************************************************************
; 如果返回的数据包是由目标主机所发的话，则显示时间和 TTL 数据
;********************************************************************
					invoke	inet_ntoa,eax
					.if	eax !=	NULL
						invoke	lstrcpy,addr @szBuffer,eax
					.endif
					invoke	GetTickCount
					sub	eax,dword ptr szBigBuffer+sizeof ip_hdr+icmp_hdr.icmp_data
					movzx	ecx,szBigBuffer + ip_hdr.ip_ttl
					invoke	wsprintf,addr szBuffer,addr szReply,\
						addr @szBuffer,PACKET_SIZE,eax,ecx
					invoke	_ConsolePrint,addr szBuffer
				.endif
			.else
				invoke	_ConsolePrint,addr szErrTimeout
			.endif
			inc	@dwID
			inc	@dwSeq
			invoke	Sleep,1000
		.endw
		invoke	closesocket,@hSocket
_Ping_Ret:
		popad
		ret

_Ping		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		call	_ConsoleInit
		invoke	_argc
		.if	eax ==	2
			invoke	WSAStartup,101h,addr stWsa
			.if	! eax
				invoke	_argv,1,addr szHostName,sizeof szHostName
				invoke	_HostnameToIP,addr szHostName
				.if	eax
					invoke	_Ping,eax
				.endif
			.endif
			invoke	WSACleanup
		.else
			invoke	_ConsolePrint,addr szHelp
		.endif
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start
