/*
 * Replacement for hb_vf... functions
 *
 * Copyright 2023 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

FUNCTION hbc_vfOpen( cFileName, nFlags )

   LOCAL pSess, pHandle

   IF cFileName = "sftp:"
      IF !Empty( pSess := _GetpSess(cFileName) )
         IF !Empty( pHandle := ssh2_Sftp_Openfile( pSess, _GetDir(cFileName), nFlags ) )
            RETURN { "sftp:", pHandle }
         ENDIF
      ENDIF
      RETURN Nil
   ENDIF
   RETURN hb_vfOpen( cFileName, nFlags )

FUNCTION hbc_vfClose( handle )

   IF Valtype( handle ) == "A"
      RETURN ssh2_Sftp_Close( handle[2] )
   ENDIF
   RETURN hb_vfClose( handle )

FUNCTION hbc_vfSeek( handle, nShift )

   IF Valtype( handle ) == "A"
      RETURN ssh2_Sftp_Seek( handle[2], nShift )
   ENDIF
   RETURN hb_vfSeek( handle, nShift )

FUNCTION hbc_vfReadLen( handle, nSize )

   IF Valtype( handle ) == "A"
      RETURN ssh2_Sftp_Readlen( handle[2], nSize )
   ENDIF
   RETURN hb_vfReadLen( handle, nSize )

FUNCTION hbc_vfWrite( handle, cBuff, nToWrite, nTimeOut )

   IF Valtype( handle ) == "A"
      RETURN ssh2_Sftp_Write( handle[2], cBuff, nToWrite )
   ENDIF
   RETURN hb_vfWrite( handle, cBuff, nToWrite, nTimeOut )

FUNCTION hbc_vfSize( cFileName )

   LOCAL pSess, nSize

   IF cFileName = "sftp:"
      IF !Empty( pSess := _GetpSess(cFileName) ) .AND. ;
         ssh2_Sftp_stat( pSess, _GetDir(cFileName), @nSize ) == 0
         RETURN nSize
      ENDIF
      RETURN -1
   ENDIF
   RETURN hb_vfSize( cFileName )

FUNCTION hbc_vfLoad( cFileName, nMaxSize )

   LOCAL pSess

   IF cFileName = "sftp:"
      RETURN Iif( Empty( pSess := _GetpSess(cFileName) ), "", hbc_ssh2_MemoRead( pSess,_GetDir(cFileName) ) )
   ENDIF
   RETURN hb_vfLoad( cFileName, nMaxSize )

FUNCTION hbc_vfDirectory( cDirSpec, cAttr )

   LOCAL pSess

   IF cDirSpec = "sftp:"
      RETURN Iif( Empty( pSess := _GetpSess(cDirSpec) ), {}, hbc_ssh2_Directory( pSess, _GetDir(cDirSpec), cAttr ) )
   ENDIF
   RETURN hb_vfDirectory( cDirSpec, cAttr )

FUNCTION hbc_vfTimeGet( cFileName, tsDateTime )

   LOCAL pSess, dDT

   IF cFileName = "sftp:"
      IF !Empty( pSess := _GetpSess(cFileName) ) .AND. ;
         ssh2_Sftp_stat( pSess, _GetDir(cFileName),, @dDT ) == 0
         tsDateTime := dDT
         RETURN .T.
      ENDIF
      RETURN .F.
   ENDIF
   RETURN hb_vfTimeGet( cFileName, @tsDateTime )

FUNCTION hbc_vfCopyFile( cFileSrc, cFileDst, aWnd )

   LOCAL pSess
   IF cFileSrc = "sftp:"
      IF cFileDst = "sftp:"
         RETURN -1
      ELSE
         RETURN Iif( Empty( pSess := _GetpSess(cFileSrc) ), -1, ;
            hbc_ssh2_Download( pSess,_GetDir(cFileSrc),cFileDst, aWnd ) )
      ENDIF
   ELSEIF cFileDst = "sftp:"
      RETURN Iif( Empty( pSess := _GetpSess(cFileDst) ), -1, ;
         hbc_ssh2_Upload( pSess,_GetDir(cFileDst),cFileSrc, aWnd ) )
   ENDIF
   RETURN edi_CopyFile( cFileSrc, cFileDst, aWnd )

FUNCTION hbc_vfDirExists( cDirName )

   LOCAL pSess
   IF cDirName = "sftp:"
      RETURN Iif( Empty( pSess := _GetpSess(cDirName) ), .F., ;
         hbc_ssh2_isDirExists( pSess, _GetDir(cDirName) ) )
   ENDIF
   RETURN hb_vfDirExists( cDirName )

FUNCTION hbc_vfExists( cFileName )

   LOCAL pSess
   IF cFileName = "sftp:"
      RETURN Iif( Empty( pSess := _GetpSess(cFileName) ), .F., ;
         hbc_ssh2_isFileExists( pSess, _GetDir(cFileName) ) )
   ENDIF
   RETURN hb_vfExists( cFileName )

FUNCTION hbc_vfRename( cFileSrc, cFileDst )

   LOCAL pSess
   IF cFileSrc = "sftp:" .OR. cFileDst = "sftp:"
      IF cFileSrc = "sftp:" .AND. cFileDst = "sftp:" .AND. !Empty( pSess := _GetpSess(cFileSrc) )
         RETURN ssh2_Sftp_Rename( pSess, _GetDir(cFileSrc), _GetDir(cFileDst ) )
      ELSE
         RETURN -1
      ENDIF
   ENDIF
   RETURN hb_vfRename( cFileSrc, cFileDst )

FUNCTION hbc_vfErase( cFileName )

   LOCAL pSess
   IF cFileName = "sftp:"
      IF !Empty( pSess := _GetpSess(cFileName) )
         IF '\' $ cFileName
            cFileName := StrTran( cFileName, '\', '/' )
         ENDIF
         RETURN ssh2_Sftp_FileDelete( pSess, _GetDir(cFileName) )
      ELSE
         RETURN -1
      ENDIF
   ENDIF
   RETURN hb_vfErase( cFileName )

FUNCTION hbc_vfDirRemove( cDirName )

   LOCAL pSess
   IF cDirName = "sftp:"
      IF !Empty( pSess := _GetpSess(cDirName) )
         IF '\' $ cDirName
            cDirName := StrTran( cDirName, '\', '/' )
         ENDIF
         RETURN ssh2_Sftp_DirDelete( pSess, _GetDir(cDirName) )
      ELSE
         RETURN -1
      ENDIF
   ENDIF
   RETURN hb_vfDirRemove( cDirName )

FUNCTION hbc_vfDirMake( cDirName )

   LOCAL pSess
   IF cDirName = "sftp:"
      IF !Empty( pSess := _GetpSess(cDirName) )
         IF '\' $ cDirName
            cDirName := StrTran( cDirName, '\', '/' )
         ENDIF
         RETURN ssh2_Sftp_MkDir( pSess, _GetDir(cDirName) )
      ELSE
         RETURN -1
      ENDIF
   ENDIF
   RETURN hb_vfDirMake( cDirName )

FUNCTION hbc_vfAttrGet( cFileName, nAttr )

   LOCAL pSess
   IF cFileName = "sftp:"
      IF '\' $ cFileName
         cFileName := StrTran( cFileName, '\', '/' )
      ENDIF
      IF !Empty( pSess := _GetpSess(cFileName) )
         RETURN .F.
      ELSE
         RETURN .F.
      ENDIF
   ENDIF
   RETURN hb_vfAttrGet( cFileName, @nAttr )

STATIC FUNCTION _GetpSess( cName )

   LOCAL nPos := cedi_Strpbrk( ":/\", cName, 6 )
   LOCAL cAddr := Iif( nPos > 0, Substr( cName, 6, nPos - 6 ), Substr( cName, 6 ) ) + ':'

   IF FilePane():aPanes[1]:net_cAddress == cAddr
      RETURN FilePane():aPanes[1]:pSess
   ELSEIF FilePane():aPanes[2]:net_cAddress == cAddr
      RETURN FilePane():aPanes[2]:pSess
   ENDIF

   RETURN Nil

STATIC FUNCTION _GetDir( cName )
   LOCAL nPos := cedi_Strpbrk( "/\", cName, 6 )
   RETURN Iif( nPos > 0, Substr( cName, nPos ), "" )