/*
 * Cmdline interface for a text editor
 *
 * Copyright 2019 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

#include "inkey.ch"
#include "setcurs.ch"

STATIC aCommands := { ;
   { "bn", @cmd_Buff() },     ;
   { "bnext", @cmd_Buff() },  ;
   { "bp", @cmd_Buff() },     ;
   { "bprev", @cmd_Buff() },  ;
   { "e", @cmd_Edit() },      ;
   { "edit", @cmd_Edit() },   ;
   { "ls", @cmd_Buff() },     ;
   { "q", @cmd_quit() },      ;
   { "q!", @cmd_quit() },     ;
   { "set", @cmd_Set() },     ;
   { "w", @cmd_Write() },     ;
   { "write", @cmd_Write() }  ;
}

STATIC s4auto, lModeSea
STATIC aKeysOpt
STATIC lEnd
STATIC cFileAdd, cCmdLine

FUNCTION mnu_CmdLine( oEdit )

   LOCAL nKey, x, y := oEdit:y2, s := "", cTemp
   LOCAL nInCmdHis := 0

   lModeSea := .F.
   lEnd := .F.

   SetColor( "W+/N" )
   Scroll( y, oEdit:x1, y, oEdit:x2 )
   oEdit:y2 --

   DevPos( oEdit:y2 + 1, oEdit:x1 )
   SetCursor( SC_NORMAL )
   DO WHILE !lEnd .AND. ( nKey := Inkey(0) ) != K_ESC

      IF nKey != K_TAB; s4auto := Nil; ENDIF
      IF lModeSea
         IF nKey == Asc( "n" )
            IF !DoSea( oEdit, Substr( s, 2 ), .T., .F. )
               edi_SetPos( oEdit, oEdit:nLine, oEdit:nPos )
            ENDIF
         ELSEIF nKey == Asc( "N" )
            IF !DoSea( oEdit, Substr( s, 2 ), .F., .F. )
               edi_SetPos( oEdit, oEdit:nLine, oEdit:nPos )
            ENDIF
         ELSEIF nKey == K_ENTER
            EXIT
         ENDIF
         LOOP
      ENDIF

      x := Col() - oEdit:x1 + 1
      IF ( nKey >= K_SPACE .AND. nKey <= 255 ) .OR. ( oEdit:lUtf8 .AND. nKey > 3000 )
         IF Left( s, 1 ) == '/' .AND. hb_hGetDef( TEdit():options, "incsearch", .F. )
            fSea( oEdit, s + cp_Chr(oEdit:lUtf8,nKey) )
         ENDIF
         s := cp_Left( oEdit:lUtf8, s, x-1 ) + cp_Chr(oEdit:lUtf8,nKey) + cp_Substr( oEdit:lUtf8, s, x )
         DevPos( y, oEdit:x1 )
         DevOut( s )
         DevPos( y, x )

      ELSEIF nKey == K_DEL
         IF x <= cp_Len( oEdit:lUtf8, s ) .AND. Left( s, 1 ) != '/'
            s := cp_Left( oEdit:lUtf8, s, x-1 ) + cp_Substr( oEdit:lUtf8, s, x+1 )
            DevPos( y, oEdit:x1 )
            DevOut( s )
            Scroll( y, cp_Len( oEdit:lUtf8, s ), y, oEdit:x2 )
            DevPos( y, x-1 )
         ENDIF

      ELSEIF nKey == K_BS
         IF x > 1
            s := cp_Left( oEdit:lUtf8, s, x-2 ) + cp_Substr( oEdit:lUtf8, s, x )
            DevPos( y, oEdit:x1 )
            DevOut( s )
            Scroll( y, cp_Len( oEdit:lUtf8, s ), y, oEdit:x2 )
            DevPos( y, x-2 )
         ENDIF

      ELSEIF nKey == K_UP
         IF ++nInCmdHis <= Len( TEdit():aCmdHis )
            Scroll( y, oEdit:x1, y, oEdit:x2 )
            s := TEdit():aCmdHis[nInCmdHis]
            DevPos( y, oEdit:x1 )
            DevOut( s )
         ELSE
            nInCmdHis --
         ENDIF

      ELSEIF nKey == K_DOWN
         IF --nInCmdHis < 0
            nInCmdHis := 0
         ELSE
            Scroll( y, oEdit:x1, y, oEdit:x2 )
            DevPos( y, 0 )
            s := Iif( nInCmdHis > 0, TEdit():aCmdHis[nInCmdHis], "" )
            DevOut( s )
         ENDIF

      ELSEIF nKey == K_LEFT
         IF x > 1 .AND. Left( s, 1 ) != '/'
            DevPos( y, x-2 )
         ENDIF

      ELSEIF nKey == K_RIGHT
         IF x <= cp_Len( oEdit:lUtf8, s )
            DevPos( y, x )
         ENDIF

      ELSEIF nKey == K_HOME
         IF Left( s, 1 ) != '/'
            DevPos( y, 0 )
         ENDIF

      ELSEIF nKey == K_END
         DevPos( y, cp_Len( oEdit:lUtf8, s ) )

      ELSEIF nKey == K_ENTER
         cmdExec( oEdit, s )
         hb_AIns( TEdit():aCmdHis, 1, s, Len(TEdit():aCmdHis)<hb_hGetDef(TEdit():options,"cmdhismax",10) )
         IF Left( s, 1 ) != '/'
            s := ""
         ENDIF
         nInCmdHis := 0

      ELSEIF nKey == K_TAB
         IF !Empty( cTemp := AutoDop( s ) )
            DevPos( y, 0 )
            DevOut( s := cTemp )
         ENDIF

      ENDIF
   ENDDO

   oEdit:y2 ++
   SetColor( oEdit:cColor )
   oEdit:TextOut()
   mnu_ChgMode( oEdit, .T. )
   IF !Empty( cFileAdd )
      IF !Empty( cTemp := MemoRead( cFileAdd ) )
         cTemp := ">" + cCmdLine + Chr(10) + cTemp
         IF ( x := Ascan( oEdit:aWindows, {|o|o:cFileName=="$Console"} ) ) > 0
            oEdit:aWindows[x]:InsText( Len(oEdit:aWindows[x]:aText)+1, 1, Chr(10)+cTemp,,, .T. )
            oEdit:aWindows[x]:lUpdated := .F.
            mnu_ToBuf( oEdit, x )
         ELSE
            edi_AddWindow( oEdit, cTemp, "$Console", 2, Int((oEdit:y2-oEdit:y1)/2) )
         ENDIF
      ENDIF
      cFileAdd := ""
   ENDIF

   RETURN Nil

STATIC FUNCTION fSea( oEdit, s )

   LOCAL lRes := DoSea( oEdit, Substr( s, 2 ), .T., .T. )

   RETURN lRes

STATIC FUNCTION cmdExec( oEdit, sCmd )

   LOCAL acmd, arr, fnc, nPos, cFileOut := "hbedit_cons.out", cBuff

   IF Left( sCmd, 1 ) == '/'
      DoSea( oEdit, Substr( sCmd, 2 ), .T., .F. )
   ELSEIF Left( sCmd, 1 ) == '!'
      IF ( nPos := At( '%', sCmd ) ) > 0
         sCmd := Left( sCmd,nPos-1 ) + oEdit:cFileName + Substr( sCmd,nPos+1 )
      ENDIF
      FErase( cFileOut )
      Scroll( oEdit:y2 + 1, oEdit:x1, oEdit:y2 + 1, oEdit:x2 )
      DevPos( oEdit:y2 + 1, oEdit:x1 )
      DevOut( "Wait..." )
      cedi_RunConsoleApp( cCmdLine := Substr( sCmd,2 ), cFileOut )
      cFileAdd := cFileOut
      lEnd := .T.
   ELSE
      acmd := hb_aTokens( sCmd )
      FOR EACH arr IN aCommands
         IF arr[1] = acmd[1]
            fnc := arr[2]
            EXIT
         ENDIF
      NEXT
      IF !Empty( fnc )
         fnc:exec( oEdit, acmd )
         Scroll( oEdit:y2+1, oEdit:x1, oEdit:y2+1, oEdit:x2 )
         DevPos( oEdit:y2+1, oEdit:x1 )
      ENDIF
   ENDIF

   RETURN Nil

STATIC FUNCTION DoSea( oEdit, s, lNext, lInc )

   LOCAL ny := oEdit:nLine, nx := oEdit:nPos
   LOCAL lRes

   IF !lInc
      DevPos( oEdit:y2+1, oEdit:x2-34 )
      DevOut( "[press n-Next,N-previous]" )
   ENDIF

   IF ( lRes := oEdit:Search( s, .T., lNext, .F., .F., @ny, @nx, lInc ) )
      IF !lInc
         DevPos( oEdit:y2+1, oEdit:x2-8 )
         DevOut( "    Found" )
         lModeSea := .T.
      ENDIF
      oEdit:GoTo( ny, nx, cp_Len( oEdit:lUtf8,s ) )
      SetColor( "W+/N" )

   ELSEIF !lInc
      DevPos( oEdit:y2+1, oEdit:x2-8 )
      DevOut( "Not found" )
      edi_SetPos( oEdit, oEdit:nLine, oEdit:nPos )
   ENDIF

   RETURN lRes

STATIC FUNCTION AutoDop( sCmd )

   LOCAL acmd := hb_aTokens( sCmd ), arr, s

   IF !Empty( s4auto )
      acmd[Len(acmd)] := s4Auto
   ELSE
      s4auto := ATail( acmd )
   ENDIF
   IF Len( acmd ) == 1
      FOR EACH arr IN aCommands
         IF arr[1] = acmd[1]
            RETURN arr[1]
         ENDIF
      NEXT
   ELSEIF Len( aCmd ) == 2
      IF aCmd[1] == "set"
         IF Empty( aKeysOpt )
            aKeysOpt := ASort( hb_hKeys( TEdit():options ) )
         ENDIF
         FOR EACH s IN aKeysOpt
            IF s = acmd[2]
               RETURN aCmd[1] + " " + s
            ENDIF
         NEXT
         ENDIF
   ENDIF

   RETURN Nil

FUNCTION cmd_Edit( oEdit, acmd )

   LOCAL cFileName, cPath

   IF Len( acmd ) > 1
      cFileName := acmd[2]
      IF Empty( hb_fnameDir(cFileName) ) .AND. !Empty( cPath := hb_fnameDir(oEdit:cFileName) )
         cFileName := cPath + cFileName
      ENDIF
      mnu_NewBuf( oEdit, cFileName )
      lEnd := .T.
   ENDIF

   RETURN Nil

FUNCTION cmd_Write( oEdit, acmd )

   LOCAL cFileName, cPath

   IF Len( acmd ) > 1
      cFileName := acmd[2]
      IF Empty( hb_fnameDir(cFileName) ) .AND. !Empty( cPath := hb_fnameDir(oEdit:cFileName) )
         cFileName := cPath + cFileName
      ENDIF
   ENDIF
   oEdit:Save( cFileName )
   lEnd := .T.

   RETURN Nil

FUNCTION cmd_Set( oEdit, acmd )

   LOCAL cmd, lOff

   IF Len( acmd ) > 1
      cmd := acmd[2]
      IF ( lOff := ( Right( cmd,1 ) == "!" ) )
         cmd := Left( cmd, Len(cmd) - 1 )
      ENDIF
      IF hb_hHaskey( oEdit:options, cmd )
         IF Len( acmd ) == 2
            hb_hSet( oEdit:options, cmd, !lOff )
         ENDIF
      ENDIF
   ENDIF

   RETURN Nil

FUNCTION cmd_Buff( oEdit, acmd )

   IF oEdit:lCtrlTab
      IF Left( acmd[1],1 ) == "l"
         mnu_Buffers( oEdit, {2, 6} )
      ELSEIF Substr( acmd[1],2,1 ) == "n"
         oEdit:lShow := .F.
         oEdit:nCurr ++
      ELSEIF Substr( acmd[1],2,1 ) == "p"
         oEdit:lShow := .F.
         oEdit:nCurr --
      ENDIF
      lEnd := .T.
   ENDIF

   RETURN Nil

FUNCTION cmd_Quit( oEdit, acmd )

   IF Substr( acmd[1],2,1 ) == "!"
      oEdit:lUpdated := .F.
   ENDIF
   mnu_Exit( oEdit )

   RETURN Nil

FUNCTION MacroError( e )

   edi_Alert( ErrorMessage( e ) )
   BREAK
RETURN .T.

