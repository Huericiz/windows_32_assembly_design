OBJS = $(NAME).obj
RES  = $(NAME).res

LINK_FLAG = /subsystem:windows
ML_FLAG = /c /coff

Server.exe Client.exe:

Server.exe: Server.obj Server.res
	Link $(LINK_FLAG) Server.obj Server.res
Client.exe: Client.obj Client.res
	Link $(LINK_FLAG) Client.obj Client.res

.asm.obj:
	ml $(ML_FLAG) $<
.rc.res:
	rc $<

clean:
	del *.obj
	del *.res
