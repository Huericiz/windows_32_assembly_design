;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 计算数据包的校验和
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CalcCheckSum	proc	_lpsz,_dwSize
		local	@dwSize

		pushad

		mov	ecx,_dwSize
		shr	ecx,1
		xor	ebx,ebx
		mov	esi,_lpsz
;********************************************************************
; 数据包校验和为每 16 位累加
;********************************************************************
		cld
		@@:
		lodsw
		movzx	eax,ax
		add	ebx,eax
		loop	@B
;********************************************************************
; 最后如果有单 8 位则继续累加
;********************************************************************
		test	_dwSize,1
		jz	@F
		lodsb
		movzx	eax,al
		add	ebx,eax
		@@:
;********************************************************************
; 将高 16 位并入低 16 位后取反输出
;********************************************************************
		mov	eax,ebx
		and	eax,0ffffh
		shr	ebx,16
		add	eax,ebx
		not	ax
		mov	@dwSize,eax
		popad
		mov	eax,@dwSize
		ret

_CalcCheckSum	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
