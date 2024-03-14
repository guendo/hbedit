
#include "fileio.ch"
#define PROTOCOL_VER "1.1"
#define  BUFFLEN   512

#define GUIS_VERSION   "1.4"

STATIC nConnType := 2
STATIC cn := e"\n"
STATIC nLogOn := 0, cLogFile := "extclient.log"
STATIC cFileRoot := "gs", cDirRoot
STATIC nInterval := 20

STATIC handlIn := -1, handlOut := -1, cBufferIn, cBufferOut, cBuffRes
STATIC lActive := .F., cVersion := "1.0"
STATIC nMyId, nHisId
STATIC lNoWait4Answer := .F.
STATIC bCallBack := Nil

FUNCTION hbExtCli()
   RETURN Nil

FUNCTION ecli_Run( cExe, nLog, cDir )

   IF Valtype( nLog ) == "N"
      nLogOn := nLog
   ENDIF

   nConnType := 2
   cDirRoot := Iif( Empty( cDir ), hb_DirTemp(), cDir )
   IF !( Right( cDirRoot,1 ) $ "\/" )
      cDirRoot += hb_ps()
   ENDIF
   gwritelog( cdirroot )
   IF !srv_conn_Create( cDirRoot + cFileRoot, .F. )
      RETURN .F.
   ENDIF

   cedi_RunBackgroundApp( cExe + ' dir="' + cDirRoot + '" ' + Iif( nLogOn>0, "log="+Str(nLogOn,1), "" ) + ;
      Iif( nConnType==2, " type=2", "" ) )

   RETURN .T.

STATIC FUNCTION CnvVal( xRes )

   LOCAL cRes := Valtype(xRes), nPos2

   IF cRes == "A"
      cRes := "Array"
   ELSEIF cRes == "O"
      cRes := "Object of " + xRes:Classname()
   ELSEIF cRes == "H"
      cRes := "Hash array"
   ELSEIF cRes == "U"
      cRes := "Nil"
   ELSEIF cRes == "C"
      cRes := xRes
   ELSEIF cRes == "L"
      cRes := Iif( xRes, "t", "f" )
   ELSE
      cRes := Trim( Transform( xReS, "@B" ) )
   ENDIF
   IF Valtype( xRes ) == "N" .AND. Rat( ".", cRes ) > 0
     nPos2 := Len( cRes )
     DO WHILE Substr( cRes, nPos2, 1 ) == '0'; nPos2 --; ENDDO
     IF Substr( cRes, nPos2, 1 ) == '.'
        nPos2 --
     ENDIF
     cRes := Left( cRes, nPos2 )
   ENDIF

   RETURN cRes

FUNCTION ecli_RunProc( cFunc, aParams )

   LOCAL i

   FOR i := 1 TO Len(aParams)
      IF Valtype( aParams[i] ) != "C"
         aParams[i] := CnvVal( aParams[i] )
      ENDIF
   NEXT
   SendOut( hb_jsonEncode( { "runproc", cFunc, hb_jsonEncode( aParams ) } ) )

   RETURN Nil

FUNCTION ecli_RunFunc( cFunc, aParams )

   LOCAL cRes := SendOut( hb_jsonEncode( { "runfunc", cFunc, hb_jsonEncode( aParams ) } ) )

   IF Left( cRes,1 ) == '"'
      RETURN Substr( cRes, 2, Len(cRes)-2 )
   ENDIF
   RETURN cRes

STATIC FUNCTION SendOut( s )

   LOCAL cRes
   gWritelog( "   " + Ltrim(Str(nConnType)) + " " + s )

   cRes := conn_Send2SocketOut( "+" + s + cn )

   RETURN Iif( Empty(cRes), "", cRes )

STATIC FUNCTION SendIn( s )

   conn_Send2SocketIn( s )

   RETURN Nil

FUNCTION MainHandler()

   LOCAL arr, cBuffer

   cBuffer := conn_GetRecvBuffer()

   gWritelog( cBuffer )

   hb_jsonDecode( cBuffer, @arr )
   IF Valtype(arr) != "A" .OR. Empty(arr)
      SendIn( "+Wrong" + cn )
      RETURN Nil
   ENDIF
   SendIn( "+Ok" + cn )

/*
   IF !Parse( arr, .F. )
      gWritelog( "Parsing error" )
   ENDIF
*/
   RETURN Nil

FUNCTION ecli_Close()

   conn_SetNoWait( .T. )
   SendOut( '["endapp"]' )
   ecli_Sleep( nInterval*2 )

   conn_Exit()
   ecli_Sleep( nInterval*2 )

   RETURN Nil

STATIC FUNCTION gWritelog( s )

   LOCAL nHand

   IF nLogOn > 0
      IF ! File( cLogFile )
         nHand := FCreate( cLogFile )
      ELSE
         nHand := FOpen( cLogFile, 1 )
      ENDIF
      FSeek( nHand, 0, 2 )
      FWrite( nHand, s + cn )
      FClose( nHand )
   ENDIF
   RETURN Nil

FUNCTION conn_SetCallBack( b )

   bCallBack := b
   RETURN Nil

FUNCTION conn_SetVersion( s )

   cVersion := s
   RETURN Nil

FUNCTION conn_Read( lOut )

   LOCAL n, nPos, s := ""
   LOCAL han := Iif( lOut, handlOut, handlIn )
   LOCAL cBuffer := Iif( lOut, cBufferOut, cBufferIn )

   FSeek( han, 1, 0 )
   DO WHILE ( n := FRead( han, @cBuffer, Len(cBuffer ) ) ) > 0
      IF ( nPos := At( Chr(10), cBuffer ) ) > 0
         s += Left( cBuffer, nPos-1 )
         EXIT
      ELSEIF n < Len(cBuffer )
         s += Left( cBuffer, n )
         EXIT
      ELSE
         s += cBuffer
      ENDIF
   ENDDO

   cBuffRes := s

   RETURN Len( s )

FUNCTION conn_GetRecvBuffer()

   RETURN Substr( cBuffRes, 2 )

FUNCTION conn_Send( lOut, cLine )

   LOCAL han := Iif( lOut, handlOut, handlIn )

   IF lActive
      FSeek( han, 1, 0 )
      FWrite( han, cLine )
      FSeek( han, 0, 0 )
      FWrite( han, Chr(nMyId) )
   ENDIF

   RETURN Nil

FUNCTION conn_Send2SocketIn( s )

   IF lActive
      conn_Send( .F., s )
   ENDIF

   RETURN Nil

FUNCTION conn_Send2SocketOut( s )

   IF lActive
      conn_Send( .T., s )
      IF !lNoWait4Answer
         DO WHILE lActive
            conn_CheckIn()
            FSeek( handlOut, 0, 0 )
            IF FRead( handlOut, @cBufferOut, 1 ) > 0 .AND. Asc( cBufferOut ) == nHisId
               conn_Read( .T. )
               gWritelog( "s2out-read: " + conn_GetRecvBuffer() )
               RETURN conn_GetRecvBuffer()
            ENDIF
            IF !Empty( bCallBack )
               Eval( bCallBack )
            ENDIF
         ENDDO
      ENDIF
   ENDIF

   RETURN Nil

FUNCTION conn_CheckIn()

   IF lActive
      FSeek( handlIn, 0, 0 )
      IF FRead( handlIn, @cBufferIn, 1 ) > 0 .AND. Asc( cBufferIn ) == nHisId
         gWritelog( "Checkin-1" )
         IF conn_Read( .F. ) > 0
            MainHandler()
         ENDIF
         RETURN .T.
      ENDIF
   ENDIF

   RETURN .F.

FUNCTION conn_SetNoWait( l )

   lNoWait4Answer := l
   RETURN Nil

FUNCTION srv_conn_Create( cFile, lRepl )

   nMyId := 2
   nHisId := 1

   handlIn := FCreate( cFile + ".gs1" )
   //hwg_writelog( cFile + ".gs1" + " " + str(handlIn) )
   FClose( handlIn )

   handlOut := FCreate( cFile + ".gs2" )
   FClose( handlOut )

   handlIn := FOpen( cFile + ".gs1", FO_READWRITE + FO_SHARED )
   gwritelog( "Open in " + cFile + ".gs1" + " " + str(handlIn) )
   handlOut := FOpen( cFile + ".gs2", FO_READWRITE + FO_SHARED )
   gwritelog( "Open out " + cFile + ".gs2" + " " + str(handlOut) )

   cBufferIn := Space( BUFFLEN )
   cBufferOut := Space( BUFFLEN )

   lActive := ( handlIn >= 0 .AND. handlOut >= 0 )

   conn_Send( .F., "+v" + cVersion + "/" + PROTOCOL_VER + Chr(10) )
   conn_Send( .T., "+Ok" + Chr(10) )
   IF lRepl
   ELSE
      //conn_Send( .T., "+v" + cVersion + "/" + PROTOCOL_VER + Chr(10) )
      //conn_Send( .F., "+Ok" + Chr(10) )
   ENDIF

   RETURN lActive

PROCEDURE conn_Exit

   lActive := .F.
   FClose( handlIn )
   FClose( handlOut )

   RETURN