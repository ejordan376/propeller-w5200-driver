'*********************************************************************************************
{
 AUTHOR: Mike Gebhard
 COPYRIGHT: Parallax Inc.
 LAST MODIFIED: 8/12/2012
 VERSION 1.0
 LICENSE: MIT (see end of file)

 DESCRIPTION:
 Socket.spin is a generic high level wrapper object for the W5200.  Socket.spin
 encapsulates a W5200 hardware socket and exposes generic socket methods. 

 ┌─────────────────┐
 │ Socket Object   │
 ├─────────────────┤
 │ W5200 Object    │
 ├─────────────────┤
 │ SPI Driver      │
 └─────────────────┘

 
 
}
'*********************************************************************************************
CON
  'MACRAW and PPPOE can only be used with socket 0
  #0, CLOSED, TCP, UDP, IPRAW, MACRAW, PPPOE

  UPD_HEADER_IP       = $00
  UDP_HEADER_PORT     = $04
  UDP_HEADER_LENGTH   = $06
  UPD_DATA            = $08

  'Increase TRANS_TIMEOUT in increments of 100*X if you are experiencing timeouts
  TRANS_TIMEOUT       = 1500   
  TIMEOUT             = TRANS_TIMEOUT * 10

  DISCONNECT_TIMEOUT  = 500  
       
VAR
  byte  _sock
  byte  _protocol
  byte  _remoteIp[4]
  byte  readCount
  word  _remotePort
  word  _dataLen
  word  _trans_timeout
  word  _timeout

DAT
  _port       word  $2710
  null        long  $00

OBJ
  wiz           : "W5200"


'----------------------------------------------------
' Initialize
'----------------------------------------------------
PUB Init(socketId, protocol, portNum)
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  _sock := socketId
  _protocol := protocol

  if(_trans_timeout == null)
    _trans_timeout := TRANS_TIMEOUT
    
  if(_timeout == null)
    _timeout := TIMEOUT
  
  'Increment port numbers stating at 10,000
  if(portNum == -1)
    portNum := _port++
    
  'wiz.Init
  wiz.InitSocket(socketId, protocol, portNum)
  wiz.SetSocketIR(_sock, $FF)
  'wiz.SetTimeToLive(_sock, 128)

  readCount := 0

PUB SetTimeout(value)
  _timeout := value

PUB SetTransactionTimeout(value)
  _trans_timeout := value

PUB GetUpdRemoteIP
  return @_remoteIp

PUB GetUpdDataLength
  return _dataLen

PUB GetUpdRemotePort
  return _remotePort

PUB Id
  return _sock

PUB GetPort
  return wiz.GetSocketPort(_sock)
  
PUB RemoteIp(octet3, octet2, octet1, octet0)
  return wiz.RemoteIp(_sock, octet3, octet2, octet1, octet0)

PUB GetRemoteIP
  return wiz.GetRemoteIp(_sock)

PUB GetStatus
  return wiz.GetSocketStatus(_sock)

PUB GetMtu
  return wiz.GetMaximumSegmentSize(_sock)

PUB GetTtl
  return wiz.GetTimeToLive(_sock)
  
PUB RemotePort(port)
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  wiz.SetRemotePort(_sock, port)
'----------------------------------------------------
'
'----------------------------------------------------

PUB Open
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  wiz.OpenSocket(_sock)

PUB Listen
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  if(wiz.IsInit(_sock))
    wiz.StartListener(_sock)
    return true
  return false

PUB Connect
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  wiz.OpenRemoteSocket(_sock)

PUB Connected
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  return wiz.IsEstablished(_sock)

PUB Close
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  return wiz.CloseSocket(_sock)

PUB IsClosed
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  return wiz.IsClosed(_sock)

PUB IsCloseWait
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  return wiz.IsCloseWait(_sock)

PUB Available | i, bytesToRead, tout
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  bytesToRead := i := 0

  if(readCount++ == 0)
    tout := _timeout 
  else
    tout := _trans_timeout

  repeat until NULL < bytesToRead := wiz.GetRxBytesToRead(_sock)
    if(i++ > tout)
      if(tout == TIMEOUT)
        readCount := 0
        return -1            'Initail request timeout
      else
        return 0             'In processes timeout

  return bytesToRead

PUB DataReady
  return wiz.GetRxBytesToRead(_sock)
    
PUB Receive(buffer, bytesToRead) | ptr
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  ptr := buffer
  wiz.Rx(_sock, buffer, bytesToRead)
  byte[buffer][bytesToRead] := null
  
  if(_protocol == UDP)
    'ParseHeader(buffer, bytesToRead)
    ptr += UPD_DATA

  return ptr
      
PUB Send(buffer, len) | bytesToWrite
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}   
  'Validate max Rx length in bytes
  bytesToWrite := len
  if(bytesToWrite > wiz.SocketTxSize(_sock))
    bytesToWrite := wiz.SocketTxSize(_sock)

  wiz.Tx(_sock, buffer, bytesToWrite)
    
  return  bytesToWrite
 
PUB SendMac(buffer, len) | bytesToWrite
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  ifnot(_protocol == UDP)
    return Send(buffer, len)
    
  'Validate max Rx length in bytes
  bytesToWrite := len
  if(len > wiz.SocketTxSize(_sock))
    bytesToWrite := wiz.SocketTxSize(_sock)

  wiz.Tx(_sock, buffer, bytesToWrite)

  return  bytesToWrite

PUB Disconnect : i
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  i := readCount := 0
  wiz.DisconnectSocket(_sock)
  repeat until wiz.IsClosed(_sock)
    if(i++ > DISCONNECT_TIMEOUT)
      wiz.CloseSocket(_sock)
      return false
  return true  


PUB GetSocketIR
  return wiz.GetSocketIR(_sock)
  
PUB SetSocketIR(value)
  wiz.SetSocketIR(_sock, value)


PRI ParseHeader(buffer, bytesToRead)
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  if(bytesToRead > 8)
    UpdHeaderIp(buffer)
    UdpHeaderPort(buffer)
    UdpHeaderDataLen(buffer)

PRI UpdHeaderIp(header)
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  _remoteIp[0] := byte[header][UPD_HEADER_IP]
  _remoteIp[1] := byte[header][UPD_HEADER_IP+1]
  _remoteIp[2] := byte[header][UPD_HEADER_IP+2]
  _remoteIp[3] := byte[header][UPD_HEADER_IP+3]

PRI UdpHeaderPort(header)
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  _remotePort := DeserializeWord(header + UDP_HEADER_PORT)

PRI UdpHeaderDataLen(header)
  _dataLen := DeserializeWord(header + UDP_HEADER_LENGTH)
    

PUB DeserializeWord(buffer) | value
{{
DESCRIPTION:

PARMS:
  
RETURNS:
  
}}
  value := byte[buffer++] << 8
  value += byte[buffer]
  return value

CON
{{
 ______________________________________________________________________________________________________________________________
|                                                   TERMS OF USE: MIT License                                                  |                                                            
|______________________________________________________________________________________________________________________________|
|Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    |     
|files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    |
|modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software|
|is furnished to do so, subject to the following conditions:                                                                   |
|                                                                                                                              |
|The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.|
|                                                                                                                              |
|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          |
|WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         |
|COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   |
|ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         |
 ------------------------------------------------------------------------------------------------------------------------------ 
}}