/*
 *
 */

FUNCTION hbc_ssh2_Connect( cAddr, nPort, cLogin, cPass )

   LOCAL pSess

   IF Empty( cLogin )
      IF !GetLogin( @cLogin, @cPass )
         RETURN .F.
      ENDIF
   ENDIF

   pSess := ssh2_Connect( cAddr, nPort )
   IF ssh2_LastRes( pSess ) != 0
      _Writelog( "1: " + cAddr + " " + Str(nPort) + " / " + Str(ssh2_LastRes(pSess)) )
      ssh2_Close( pSess )
      RETURN Nil
   ENDIF
   IF !ssh2_Login( pSess, cLogin, cPass )
      _Writelog( "2:" )
      ssh2_Close( pSess )
      RETURN Nil
   ENDIF
   IF ssh2_Sftp_Init( pSess ) != 0
      _Writelog( "3:" )
      ssh2_Close( pSess )
      RETURN Nil
   ENDIF

   RETURN pSess

FUNCTION hb_ssh2_Directory( pSess, cDirSpec )

   LOCAL aDir := {}, cDir := hb_fnameDir( cDirSpec )
   LOCAL cName, nAttr, nSize, dDate, cAttr

   IF ssh2_Sftp_OpenDir( pSess, cDir ) == 0
      DO WHILE !Empty( cName := ssh2_Sftp_ReadDir( pSess, @nSize, @dDate, @nAttr ) )
         cAttr := Iif( hb_BitAnd( nAttr, 0x4000 ) > 0, "D", "" )
         Aadd( aDir, { cName, nSize, dDate, "", cAttr } )
      ENDDO
   ELSE
      _Writelog( "Opendir error " + cDir )
   ENDIF

   RETURN aDir

STATIC FUNCTION GetLogin( cLogin, cPass )
   LOCAL y1 := 5, x1 := Int(MaxCol()/2)-15, x2 := x1+30
   LOCAL cBuf, oldc := SetColor( TEdit():cColorSel + "," + TEdit():cColorMenu )
   LOCAL aGets := { ;
      {y1+1,x1+2, 11, "Login:"}, ;
      { y1+1,x1+10, 0, "", x2-x1-12 }, ;
      {y1+2,x1+2, 11, "Passw:"}, ;
      { y1+2,x1+10, 0, "", x2-x1-12,,,1 } }

      cBuf := Savescreen( y1, x1, y1 + 3, x2 )
      @ y1, x1, y1 + 3, x2 BOX "�Ŀ����� "

      edi_READ( aGets )
      IF LastKey() == 13
         cLogin := aGets[2,4]
         cPass  := aGets[4,4]
      ENDIF
      Restscreen( y1, x1, y1 + 3, x2, cBuf )

   RETURN .T.

STATIC FUNCTION _Writelog( cText )
   RETURN edi_Writelog( Dtoc(Date())+" "+Time()+" " + cText, "hbcnet.err" )

EXIT PROCEDURE hbcExit

   ssh2_Exit()

   RETURN
