# Kernel: sgemm_nn_128x32

# Copyright 2014 Nervana Systems Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
&C  0x140
&A  0x148
&B  0x150
&alpha  0x158
&beta   0x15c
&flags  0x160
&lda    0x164
&ldb    0x168
&ldc    0x16c
&m      0x170
&n      0x174
&k      0x178
&zero   0x17c
&zero   0x180
&zero   0x184
&one    0x188



<REGISTER_MAPPING>

    32-79 ~ lda, ldb, ldaz, lda32, ldbz, ta00, ta32, ta64, ta96, tb, tid1, tid3, tidAX, tidBX, tidAY<1-3>, txb<1-3>, xmad_ta, shiftAX

    0-31 : czero<00-31>

     3, 2,11,10 : cx<0-3>y0
     7, 6,15,14 : cx<0-3>y1
     1, 0, 9, 8 : cx<0-3>y2
     5, 4,13,12 : cx<0-3>y3
    19,18,27,26 : cx<0-3>y4
    23,22,31,30 : cx<0-3>y5
    17,16,25,24 : cx<0-3>y6
    21,20,29,28 : cx<0-3>y7

      32-43 : j0Ay<0-7>, j0Bx<0-3>
      44-55 : j1Ay<0-7>, j1Bx<0-3>
      56-67 : j2Ay<0-7>, j2Bx<0-3>
      68-79 : j3Ay<0-7>, j3Bx<0-3>

      80-83 : loadB<0-3>
      84-99 : load0A<0-3>, load1A<0-3>, load2A<0-3>, load3A<0-3>

    100-109 : trackB<0-1>, track0A<0-1>, track1A<0-1>, track2A<0-1>, track3A<0-1>

    110-120 ~ writeAs, writeBs, ldb16, k, tidAY, tidBY, txb, txa00, txa32, txa64, txa96
    121-127 ~ swapBuf, readAs, readBs, tid, blkA, blkB, blkZ

    32-39 : C00y<0-1>, C04y<0-1>, C08y<0-1>, C12y<0-1>
    40-47 : c<0-3>, d3, d2, d1, d0
   48-120 ~ tid31, tid96, ldc, ldcz, cx, ci, xmad_c, ldc1, ldc4, ldc60, writeCs, readCs, cy<00|04|08|12>, alpha, beta, flags

</REGISTER_MAPPING>

--:-:1:-:1      S2R tid,  SR_TID.X;   //128个线程，threadIdx.x=128，最终还是二维(8x16)
--:-:2:-:1      S2R blkA, SR_CTAID.Y;   //blkA=bid.y
--:-:3:-:1      S2R blkB, SR_CTAID.Z;   //blkB=bid.z
--:-:4:-:1      S2R blkZ, SR_CTAID.X;  //blockIdx.x = 1


//初始化shared为0，为了后续初始化c寄存器
--:-:-:-:1      STS.128 [4x<(128*16 + 32)*2 + 32*16*2>], RZ;  //初始化shared为0，为了后续初始化c寄存器
--:-:-:-:1      LDS.U.128 czero00, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero04, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero08, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero12, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero16, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero20, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero24, [4x<(128*16 + 32)*2 + 32*16*2>];
--:-:-:-:1      LDS.U.128 czero28, [4x<(128*16 + 32)*2 + 32*16*2>];



--:-:-:-:0      MOV lda, c[0x0][0x164];   //lda = lda
--:-:-:-:0      MOV ldaz, c[0x0][0x17c];  //ldaz = 0
--:-:-:-:0      MOV ldb, c[0x0][0x168];   //ldb
--:-:-:-:1      MOV ldbz, c[0x0][0x180];  //ldbz = 0

//计算A地址偏移
01:-:-:-:0      SHR.U32 tidAX, tid, 2;   //tidAX=tid >>2;0,1,2,3 -> 4,5,6,7 -> 1 
01:-:-:-:0      LOP.AND tid3, tid, 3;  //tid3=tid & 0x3 ,常用来给tid分组,讲tid分为4组，分别为00，01，10，11
--:-:-:-:0      SHL tidAY, tid3, 2;   //tidAY = (tid & 0x3) << 0x2
02:-:-:-:0      ISCADD txa00, blkA, tidAX, 7;  /txa00 = bid.y * 128 + tid>>2
--:-:-:-:0      SHL lda32, lda, 5;   //lda32 = lda * 32
//ta00 = lda * txa00 + tidAY
--:-:-:-:1      XMAD.MRG xmad_ta, lda, txa00.H1, RZ;
--:-:-:-:1      XMAD ta00, lda, txa00, tidAY;
--:-:-:-:1      XMAD.PSL.CBCC ta00, lda.H1, xmad_ta.H1, ta00;
//ta00 = ldaz * blkZ + ta00
08:-:-:-:1      XMAD ta00, ldaz, blkZ, ta00;
08:-:-:-:1      XMAD.PSL ta00, ldaz.H1, blkZ, ta00;
//计算A的第一个地址
--:-:-:-:1      LEA track0A0.CC, ta00, c[0x0][0x148], 2;
--:-:-:-:1      IADD ta32, ta00, lda32;
--:-:-:-:1      LEA.HI.X track0A1, ta00, c[0x0][0x14c], RZ, 2;
--:-:-:-:1      IADD txa96, txa00, 96;
//计算A的第二个地址
--:-:-:-:1      LEA track1A0.CC, ta32, c[0x0][0x148], 2;
--:-:-:-:1      IADD ta64, ta32, lda32;
--:-:-:-:2      LEA.HI.X track1A1, ta32, c[0x0][0x14c], RZ, 2;

--:-:-:-:1      IADD ta96, ta64, lda32;
//计算A的第三个地址
--:-:-:-:2      LEA track2A0.CC, ta64, c[0x0][0x148], 2;
--:-:-:-:3      LEA.HI.X track2A1, ta64, c[0x0][0x14c], RZ, 2;
//计算A的第四个地址
--:-:-:-:2      LEA track3A0.CC, ta96, c[0x0][0x148], 2;
--:-:-:-:1      LEA.HI.X track3A1, ta96, c[0x0][0x14c], RZ, 2;
//track0A0, trakc0A1; track1A0, track1A1; track2A0, track2A1; track3A0,track3A1; array A 每个thread load 16个data
//trackB0, trakcB1   array B 每个thread load 4个data
//A地址计算结束



//计算B地址偏移
01:-:-:-:0      LOP.AND tidBX, tid, 7;   //tidBX =tid & 0x7,每组8个thread
--:-:-:-:1      SHR.U32 tidBY, tid, 3;   //tidBY = tid >> 0x3=tid / 8，分128/8=32组，每组8个thread
--:-:-:-:1      SHL tidBX, tidBX, 2;   //tidBX = tidBX << 0x2 = (tid&0x7)<<0x2
//tb=ldb*tidBY+txb
--:-:-:-:1      SHR.U32 ldb, ldb, 5;
04:-:-:-:1      ISCADD txb, blkB, tidBX, 5;
--:-:-:-:1      XMAD tb, ldb, tidBY, txb; //tb=ldb * tidBy + txb, ldb =blockSize?
--:-:-:-:1      XMAD.PSL tb, ldb.H1, tidBY, tb;
//tb=ldbz*blkZ+tb
08:-:-:-:1      XMAD tb, ldbz, blkZ, tb; //tb = ldbz * blkZ + trackB
08:-:-:-:1      XMAD.PSL tb, ldbz.H1, blkZ, tb;
//计算B的地址
--:-:-:-:2      LEA trackB0.CC, tb, c[0x0][0x150], 2;   //tb B array index
--:-:-:-:1      LEA.HI.X trackB1, tb, c[0x0][0x154], RZ, 2;
//B地址计算结束

//计算shared memory读写地址，doubel buffer
--:-:-:-:1      SHL shiftAX, tid3, 3;
--:-:-:-:1      LOP.AND readAs, tid, 0x70;

--:-:-:-:1      LOP.AND tid1, tid, 1;

--:-:-:-:1      ISCADD writeBs, tidBY, tidBX, 5;
--:-:-:-:1      MOV k, c[0x0][0x178];
--:-:-:-:1      SHR.U32 readAs, readAs, 3;

--:-:-:-:1      BFE.U32 readBs, tid, 0x301; // 3 bits at position 1
--:-:-:-:1      SHL ldb16, ldb, 6;
--:-:-:-:1      ISCADD writeBs, writeBs, 4x<(128*16 + 32)*2 + 32*16>, 2;
-
--:-:-:-:1      ISCADD readBs, readBs, 4x<(128*16 + 32)>, 4;

--:-:-:-:1      LOP.OR readAs, readAs, tid1;

//shared A的写地址
--:-:-:-:1      ISCADD writeAs, tidAY, tidAX, 7;
--:-:-:-:1      IADD writeAs, writeAs, shiftAX;
//下一个写的地址
--:-:-:-:1      ISCADD writeAs, writeAs, 4x<(128*16 + 32) + 32*16>, 2;
--:-:-:-:1      IADD txa32, txa00, 32;

--:-:-:-:1      IADD txa64, txa00, 64;


--:-:-:-:1      SHL readAs, readAs, 4;

--:-:-:-:1      MOV32I swapBuf, -4x<(128*16 + 32) + 32*16>;  //double buffer shared memory


REMAINDER:

--:-:-:-:1      IADD tidAY1, tidAY, 1;
--:-:-:-:1      ISETP.LT.AND P4, PT, txa00, c[0x0][0x170], PT;
--:-:-:-:1      IADD tidAY2, tidAY, 2;
--:-:-:-:1      ISETP.LT.AND P5, PT, txa32, c[0x0][0x170], PT;
--:-:-:-:1      IADD tidAY3, tidAY, 3;
--:-:-:-:1      ISETP.LT.AND P6, PT, tidBY, k, PT;
--:-:-:-:1      IADD txb1, txb, 1;
--:-:-:-:1      IADD txb2, txb, 2;
--:-:-:Y:6      IADD txb3, txb, 3;
--:-:-:-:2      ISETP.LT.AND P0, PT, tidAY, k, P4;
--:-:-:-:2      ISETP.LT.AND P1, PT, tidAY1, k, P4;
--:-:-:-:2      ISETP.LT.AND P2, PT, tidAY2, k, P4;
--:-:-:-:2      ISETP.LT.AND P3, PT, tidAY3, k, P4;
--:-:-:Y:5      ISETP.LT.AND P4, PT, txa64, c[0x0][0x170], PT;
--:-:-:-:0 @!P0 MOV load0A0, RZ;
--:-:1:-:1  @P0 LDG.E.CI load0A0, [track0A + 4x<0>];
--:-:-:-:1      ISETP.LT.AND P0, PT, tidAY, k, P5;
--:-:-:-:0 @!P1 MOV load0A1, RZ;
--:-:1:-:1  @P1 LDG.E.CI load0A1, [track0A + 4x<1>];
--:-:-:-:1      ISETP.LT.AND P1, PT, tidAY1, k, P5;
--:-:-:-:0 @!P2 MOV load0A2, RZ;
--:-:1:-:1  @P2 LDG.E.CI load0A2, [track0A + 4x<2>];
--:-:-:-:1      ISETP.LT.AND P2, PT, tidAY2, k, P5;
--:-:-:-:0 @!P3 MOV load0A3, RZ;
--:-:1:-:1  @P3 LDG.E.CI load0A3, [track0A + 4x<3>];
--:-:-:-:2      ISETP.LT.AND P3, PT, tidAY3, k, P5;
--:-:-:Y:5      ISETP.LT.AND P5, PT, txa96, c[0x0][0x170], PT;
--:-:-:-:0 @!P0 MOV load1A0, RZ;
--:-:2:-:1  @P0 LDG.E.CI load1A0, [track1A + 4x<0>];
--:-:-:-:1      ISETP.LT.AND P0, PT, tidAY, k, P4;
--:-:-:-:0 @!P1 MOV load1A1, RZ;
--:-:2:-:1  @P1 LDG.E.CI load1A1, [track1A + 4x<1>];
--:-:-:-:1      ISETP.LT.AND P1, PT, tidAY1, k, P4;
--:-:-:-:0 @!P2 MOV load1A2, RZ;
--:-:2:-:1  @P2 LDG.E.CI load1A2, [track1A + 4x<2>];
--:-:-:-:1      ISETP.LT.AND P2, PT, tidAY2, k, P4;
--:-:-:-:0 @!P3 MOV load1A3, RZ;
--:-:2:-:1  @P3 LDG.E.CI load1A3, [track1A + 4x<3>];
--:-:-:-:2      ISETP.LT.AND P3, PT, tidAY3, k, P4;
--:-:-:Y:5      ISETP.GE.AND P4, PT, k, 32, P4;
--:-:-:-:0 @!P0 MOV load2A0, RZ;
--:-:3:-:1  @P0 LDG.E.CI load2A0, [track2A + 4x<0>];
--:-:-:-:1      ISETP.LT.AND P0, PT, tidAY, k, P5;
--:-:-:-:0 @!P1 MOV load2A1, RZ;
--:-:3:-:1  @P1 LDG.E.CI load2A1, [track2A + 4x<1>];
--:-:-:-:1      ISETP.LT.AND P1, PT, tidAY1, k, P5;
--:-:-:-:0 @!P2 MOV load2A2, RZ;
--:-:3:-:1  @P2 LDG.E.CI load2A2, [track2A + 4x<2>];
--:-:-:-:1      ISETP.LT.AND P2, PT, tidAY2, k, P5;
--:-:-:-:0 @!P3 MOV load2A3, RZ;
--:-:3:-:1  @P3 LDG.E.CI load2A3, [track2A + 4x<3>];
--:-:-:-:2      ISETP.LT.AND P3, PT, tidAY3, k, P5;
--:-:-:Y:5      ISETP.GE.AND P5, PT, k, 32, P5;
--:-:-:-:0 @!P0 MOV load3A0, RZ;
--:-:4:-:1  @P0 LDG.E.CI load3A0, [track3A + 4x<0>];
--:-:-:-:1      ISETP.LT.AND P0, PT, txb, c[0x0][0x174], P6;
--:-:-:-:0 @!P1 MOV load3A1, RZ;
--:-:4:-:1  @P1 LDG.E.CI load3A1, [track3A + 4x<1>];
--:-:-:-:1      ISETP.LT.AND P1, PT, txb1, c[0x0][0x174], P6;
--:-:-:-:0 @!P2 MOV load3A2, RZ;
--:-:4:-:1  @P2 LDG.E.CI load3A2, [track3A + 4x<2>];
--:-:-:-:1      ISETP.LT.AND P2, PT, txb2, c[0x0][0x174], P6;
--:-:-:-:0 @!P3 MOV load3A3, RZ;
--:-:4:-:1  @P3 LDG.E.CI load3A3, [track3A + 4x<3>];
--:-:-:-:2      ISETP.LT.AND P3, PT, txb3, c[0x0][0x174], P6;
--:-:-:Y:5      ISETP.LT.AND P6, PT, txb, c[0x0][0x174], PT;
--:-:-:-:0 @!P0 MOV loadB0, RZ;
--:-:5:-:2  @P0 LDG.E.CI loadB0, [trackB + 4x<0>];
--:-:-:-:0 @!P1 MOV loadB1, RZ;
--:-:5:-:1  @P1 LDG.E.CI loadB1, [trackB + 4x<1>];
--:-:-:-:1      LOP.AND.NZ P1, RZ, k, 15;
--:-:-:-:0 @!P2 MOV loadB2, RZ;
--:-:5:-:1  @P2 LDG.E.CI loadB2, [trackB + 4x<2>];
--:-:-:-:1      ISETP.LT.AND P2, PT, txa00, c[0x0][0x170], PT;
--:-:-:-:0 @!P3 MOV loadB3, RZ;
--:-:5:-:1  @P3 LDG.E.CI loadB3, [trackB + 4x<3>];
--:-:-:-:2      ISETP.LT.AND P3, PT, txa32, c[0x0][0x170], PT;
--:-:-:Y:7      ISETP.GE.AND P6, PT, k, 32, P6;
--:-:-:-:2      ISETP.GT.AND P1, PT, k, 16, P1;
--:-:-:-:2      ISETP.GE.AND P2, PT, k, 32, P2;
--:-:-:-:1      ISETP.GE.AND P3, PT, k, 32, P3;

21:-:-:-:1      STS [writeAs + 4x<0*128 + 0*32>], load0A0;
--:-:-:-:0      IADD   track0A0.CC, track0A0, 4x<16>;
--:-:-:-:1      STS [writeAs + 4x<1*128 + 0*32>], load0A1;
--:-:-:-:1      STS [writeAs + 4x<2*128 + 0*32>], load0A2;
--:-:-:-:4      STS [writeAs + 4x<3*128 + 0*32>], load0A3;

--:-:-:-:0      IADD.X track0A1,    track0A1, RZ;

02:-:-:-:1      STS [writeAs + 4x<0*128 + 1*32>], load1A0;
--:-:-:-:0      IADD   track1A0.CC, track1A0, 4x<16>;
--:-:-:-:1      STS [writeAs + 4x<1*128 + 1*32>], load1A1;
--:-:-:-:1      STS [writeAs + 4x<2*128 + 1*32>], load1A2;
--:-:-:-:4      STS [writeAs + 4x<3*128 + 1*32>], load1A3;

--:-:-:-:0      IADD.X track1A1,    track1A1, RZ;

04:-:-:-:1      STS [writeAs + 4x<0*128 + 2*32>], load2A0;
--:-:-:-:0      IADD   track2A0.CC, track2A0, 4x<16>;
--:-:-:-:1      STS [writeAs + 4x<1*128 + 2*32>], load2A1;
--:-:-:-:1      STS [writeAs + 4x<2*128 + 2*32>], load2A2;
--:-:-:-:4      STS [writeAs + 4x<3*128 + 2*32>], load2A3;

--:-:-:-:0      IADD.X track2A1,    track2A1, RZ;

08:-:-:-:1      STS [writeAs + 4x<0*128 + 3*32>], load3A0;
--:-:-:-:0      IADD   track3A0.CC, track3A0, 4x<16>;
--:-:-:-:1      STS [writeAs + 4x<1*128 + 3*32>], load3A1;
--:-:-:-:1      STS [writeAs + 4x<2*128 + 3*32>], load3A2;
--:-:-:-:4      STS [writeAs + 4x<3*128 + 3*32>], load3A3;

--:-:-:-:0      IADD.X track3A1,    track3A1, RZ;

10:-:-:-:1      STS.128 [writeBs], loadB;
--:-:-:-:1      IADD   trackB0.CC, trackB0, ldb16;

--:-:-:-:1      IADD readBs,  readBs, -swapBuf;
--:-:-:-:0      IADD readAs,  readAs, -swapBuf;
--:-:-:-:5      BAR.SYNC 0;
--:-:-:-:1      IADD writeBs, writeBs, swapBuf;
--:-:-:-:1      IADD writeAs, writeAs, swapBuf;
--:-:-:-:1      IADD swapBuf, RZ, -swapBuf;

--:-:-:-:0      IADD.X trackB1, trackB1, RZ;


--:-:3:-:1  @P2 LDG.E.CI load0A0, [track0A + 4x<0>];
--:-:3:-:1  @P2 LDG.E.CI load0A1, [track0A + 4x<1>];
--:-:3:-:1  @P2 LDG.E.CI load0A2, [track0A + 4x<2>];
--:-:3:-:1  @P2 LDG.E.CI load0A3, [track0A + 4x<3>];

--:-:4:-:1  @P3 LDG.E.CI load1A0, [track1A + 4x<0>];
--:-:4:-:1  @P3 LDG.E.CI load1A1, [track1A + 4x<1>];
--:-:4:-:1  @P3 LDG.E.CI load1A2, [track1A + 4x<2>];
--:-:4:-:1  @P3 LDG.E.CI load1A3, [track1A + 4x<3>];

--:-:5:-:1  @P4 LDG.E.CI load2A0, [track2A + 4x<0>];
--:-:5:-:1  @P4 LDG.E.CI load2A1, [track2A + 4x<1>];
--:-:5:-:1  @P4 LDG.E.CI load2A2, [track2A + 4x<2>];
--:-:5:-:1  @P4 LDG.E.CI load2A3, [track2A + 4x<3>];

--:-:5:-:1  @P5 LDG.E.CI load3A0, [track3A + 4x<0>];
--:-:5:-:1  @P5 LDG.E.CI load3A1, [track3A + 4x<1>];
--:-:5:-:1  @P5 LDG.E.CI load3A2, [track3A + 4x<2>];
--:-:5:-:1  @P5 LDG.E.CI load3A3, [track3A + 4x<3>];

--:-:6:-:1  @P6 LDG.E.CI loadB0, [trackB + 4x<0>];
--:-:6:-:1  @P6 LDG.E.CI loadB1, [trackB + 4x<1>];
--:-:6:-:1  @P6 LDG.E.CI loadB2, [trackB + 4x<2>];
--:-:6:-:1  @P6 LDG.E.CI loadB3, [trackB + 4x<3>];
    

# sgemm_common_128x32

# Copyright 2014 Nervana Systems Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


--:-:1:-:1      LDS.U.128 j0Ay0, [readAs + 4x<0*128 + 00 + 0*8>];
--:-:1:-:1      LDS.U.128 j0Bx0, [readBs + 4x<0*32  + 00 + 0*8>];
--:-:1:-:1      LDS.U.128 j0Ay4, [readAs + 4x<0*128 + 64 + 0*8>];
--:-:2:-:1      LDS.U.128 j1Ay0, [readAs + 4x<1*128 + 00 + 0*8>];
--:-:2:-:1      LDS.U.128 j1Bx0, [readBs + 4x<1*32  + 00 + 0*8>];
--:-:2:-:1      LDS.U.128 j1Ay4, [readAs + 4x<1*128 + 64 + 0*8>];

LOOP:

01:-:-:-:0      FFMA cx0y2, j0Bx0, j0Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j2Ay0, [readAs + 4x<2*128 + 00 + 0*8>];
--:-:-:-:1      FFMA cx1y2, j0Bx1, j0Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j0Bx1, j0Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j2Bx0, [readBs + 4x<2*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j0Bx0, j0Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j0Bx0, j0Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j2Ay4, [readAs + 4x<2*128 + 64 + 0*8>];
--:-:-:-:1      FFMA cx1y3, j0Bx1, j0Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j0Bx1, j0Ay1, cx1y1;
--:-:-:-:1      IADD k, k, -16;
--:-:-:-:1      FFMA cx0y1, j0Bx0, j0Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j0Bx0, j0Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j0Bx1, j0Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j0Bx1, j0Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j0Bx0, j0Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j0Bx0, j0Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j0Bx1, j0Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j0Bx1, j0Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P0, PT, k, 16, PT;
--:-:-:-:1      FFMA cx0y5, j0Bx0, j0Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j0Bx2, j0Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j0Bx3, j0Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j0Bx3, j0Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j0Bx2, j0Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j0Bx2, j0Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j0Bx3, j0Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j0Bx3, j0Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j0Bx2, j0Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j0Bx2, j0Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j0Bx3, j0Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j0Bx3, j0Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j0Bx2, j0Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j0Bx2, j0Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j0Bx3, j0Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j0Bx3, j0Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j0Bx2, j0Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j1Bx0, j1Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j3Ay0, [readAs + 4x<3*128 + 00 + 0*8>];
--:-:-:-:1      FFMA cx1y2, j1Bx1, j1Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j1Bx1, j1Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j3Bx0, [readBs + 4x<3*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j1Bx0, j1Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j1Bx0, j1Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j3Ay4, [readAs + 4x<3*128 + 64 + 0*8>];
--:-:-:-:1      FFMA cx1y3, j1Bx1, j1Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j1Bx1, j1Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j1Bx0, j1Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j1Bx0, j1Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j1Bx1, j1Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j1Bx1, j1Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j1Bx0, j1Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j1Bx0, j1Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j1Bx1, j1Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j1Bx1, j1Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j1Bx0, j1Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j1Bx2, j1Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j1Bx3, j1Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j1Bx3, j1Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j1Bx2, j1Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j1Bx2, j1Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j1Bx3, j1Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j1Bx3, j1Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j1Bx2, j1Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j1Bx2, j1Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j1Bx3, j1Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j1Bx3, j1Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j1Bx2, j1Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j1Bx2, j1Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j1Bx3, j1Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j1Bx3, j1Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j1Bx2, j1Ay0, cx2y0;
01:-:-:-:0      FFMA cx0y2, j2Bx0, j2Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j0Ay0, [readAs + 4x<4*128 + 00 + 1*8>];
--:-:-:-:1      FFMA cx1y2, j2Bx1, j2Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j2Bx1, j2Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j0Bx0, [readBs + 4x<4*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j2Bx0, j2Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j2Bx0, j2Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j0Ay4, [readAs + 4x<4*128 + 64 + 1*8>];
--:-:-:-:1      FFMA cx1y3, j2Bx1, j2Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j2Bx1, j2Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j2Bx0, j2Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j2Bx0, j2Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j2Bx1, j2Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j2Bx1, j2Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j2Bx0, j2Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j2Bx0, j2Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j2Bx1, j2Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j2Bx1, j2Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j2Bx0, j2Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j2Bx2, j2Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j2Bx3, j2Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j2Bx3, j2Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j2Bx2, j2Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j2Bx2, j2Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j2Bx3, j2Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j2Bx3, j2Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j2Bx2, j2Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j2Bx2, j2Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j2Bx3, j2Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j2Bx3, j2Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j2Bx2, j2Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j2Bx2, j2Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j2Bx3, j2Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j2Bx3, j2Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j2Bx2, j2Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j3Bx0, j3Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j1Ay0, [readAs + 4x<5*128 + 00 + 1*8>];
--:-:-:-:1      FFMA cx1y2, j3Bx1, j3Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j3Bx1, j3Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j1Bx0, [readBs + 4x<5*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j3Bx0, j3Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j3Bx0, j3Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j1Ay4, [readAs + 4x<5*128 + 64 + 1*8>];
--:-:-:-:1      FFMA cx1y3, j3Bx1, j3Ay3, cx1y3;
--:-:-:-:0      FFMA cx1y1, j3Bx1, j3Ay1, cx1y1;
04:-:-:-:1  @P0 STS [writeAs + 4x<0*128 + 0*32>], load0A0;
--:-:-:-:1      FFMA cx0y1, j3Bx0, j3Ay1, cx0y1;
--:-:-:-:1  @P2 IADD   track0A0.CC, track0A0, 4x<16>;
--:-:-:-:0      FFMA cx0y6, j3Bx0, j3Ay6, cx0y6;
--:-:-:-:1  @P0 STS [writeAs + 4x<1*128 + 0*32>], load0A1;
--:-:-:-:1      FFMA cx1y6, j3Bx1, j3Ay6, cx1y6;
--:-:-:-:0      FFMA cx1y4, j3Bx1, j3Ay4, cx1y4;
--:-:-:-:1  @P0 STS [writeAs + 4x<2*128 + 0*32>], load0A2;
--:-:-:-:1      FFMA cx0y4, j3Bx0, j3Ay4, cx0y4;
--:-:-:-:0      FFMA cx0y7, j3Bx0, j3Ay7, cx0y7;
--:3:-:-:1  @P0 STS [writeAs + 4x<3*128 + 0*32>], load0A3;
--:-:-:-:1      FFMA cx1y7, j3Bx1, j3Ay7, cx1y7;
--:-:-:-:1  @P2 IADD.X track0A1,    track0A1, RZ;
--:-:-:-:1      FFMA cx1y5, j3Bx1, j3Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P2, PT, k, 32, P2;
--:-:-:-:1      FFMA cx0y5, j3Bx0, j3Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j3Bx2, j3Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j3Bx3, j3Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j3Bx3, j3Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j3Bx2, j3Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j3Bx2, j3Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j3Bx3, j3Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j3Bx3, j3Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j3Bx2, j3Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j3Bx2, j3Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j3Bx3, j3Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j3Bx3, j3Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j3Bx2, j3Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j3Bx2, j3Ay2, cx2y2;
--:-:-:-:0      FFMA cx3y2, j3Bx3, j3Ay2, cx3y2;
04:-:-:-:1  @P2 LDG.E.CI load0A0, [track0A + 4x<0>];
--:-:-:-:1      FFMA cx3y0, j3Bx3, j3Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j3Bx2, j3Ay0, cx2y0;
--:-:-:-:1  @P2 LDG.E.CI load0A1, [track0A + 4x<1>];
01:-:-:-:0      FFMA cx0y2, j0Bx0, j0Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j2Ay0, [readAs + 4x<6*128 + 00 + 1*8>];
--:-:-:-:0      FFMA cx1y2, j0Bx1, j0Ay2, cx1y2;
--:-:-:-:1  @P2 LDG.E.CI load0A2, [track0A + 4x<2>];
--:-:-:-:0      FFMA cx1y0, j0Bx1, j0Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j2Bx0, [readBs + 4x<6*32  + 00 + 0*8>];
--:-:-:-:0      FFMA cx0y0, j0Bx0, j0Ay0, cx0y0;
--:-:3:-:1  @P2 LDG.E.CI load0A3, [track0A + 4x<3>];
--:-:-:-:0      FFMA cx0y3, j0Bx0, j0Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j2Ay4, [readAs + 4x<6*128 + 64 + 1*8>];
--:-:-:-:1      FFMA cx1y3, j0Bx1, j0Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j0Bx1, j0Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j0Bx0, j0Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j0Bx0, j0Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j0Bx1, j0Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j0Bx1, j0Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j0Bx0, j0Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j0Bx0, j0Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j0Bx1, j0Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j0Bx1, j0Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j0Bx0, j0Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j0Bx2, j0Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j0Bx3, j0Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j0Bx3, j0Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j0Bx2, j0Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j0Bx2, j0Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j0Bx3, j0Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j0Bx3, j0Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j0Bx2, j0Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j0Bx2, j0Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j0Bx3, j0Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j0Bx3, j0Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j0Bx2, j0Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j0Bx2, j0Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j0Bx3, j0Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j0Bx3, j0Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j0Bx2, j0Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j1Bx0, j1Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j3Ay0, [readAs + 4x<7*128 + 00 + 1*8>];
--:-:-:-:1      FFMA cx1y2, j1Bx1, j1Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j1Bx1, j1Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j3Bx0, [readBs + 4x<7*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j1Bx0, j1Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j1Bx0, j1Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j3Ay4, [readAs + 4x<7*128 + 64 + 1*8>];
--:-:-:-:1      FFMA cx1y3, j1Bx1, j1Ay3, cx1y3;
--:-:-:-:0      FFMA cx1y1, j1Bx1, j1Ay1, cx1y1;
08:-:-:-:1  @P0 STS [writeAs + 4x<0*128 + 1*32>], load1A0;
--:-:-:-:1      FFMA cx0y1, j1Bx0, j1Ay1, cx0y1;
--:-:-:-:1  @P3 IADD   track1A0.CC, track1A0, 4x<16>;
--:-:-:-:0      FFMA cx0y6, j1Bx0, j1Ay6, cx0y6;
--:-:-:-:1  @P0 STS [writeAs + 4x<1*128 + 1*32>], load1A1;
--:-:-:-:1      FFMA cx1y6, j1Bx1, j1Ay6, cx1y6;
--:-:-:-:0      FFMA cx1y4, j1Bx1, j1Ay4, cx1y4;
--:-:-:-:1  @P0 STS [writeAs + 4x<2*128 + 1*32>], load1A2;
--:-:-:-:1      FFMA cx0y4, j1Bx0, j1Ay4, cx0y4;
--:-:-:-:0      FFMA cx0y7, j1Bx0, j1Ay7, cx0y7;
--:4:-:-:1  @P0 STS [writeAs + 4x<3*128 + 1*32>], load1A3;
--:-:-:-:1      FFMA cx1y7, j1Bx1, j1Ay7, cx1y7;
--:-:-:-:1  @P3 IADD.X track1A1,    track1A1, RZ;
--:-:-:-:1      FFMA cx1y5, j1Bx1, j1Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P3, PT, k, 32, P3;
--:-:-:-:1      FFMA cx0y5, j1Bx0, j1Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j1Bx2, j1Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j1Bx3, j1Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j1Bx3, j1Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j1Bx2, j1Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j1Bx2, j1Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j1Bx3, j1Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j1Bx3, j1Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j1Bx2, j1Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j1Bx2, j1Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j1Bx3, j1Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j1Bx3, j1Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j1Bx2, j1Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j1Bx2, j1Ay2, cx2y2;
--:-:-:-:0      FFMA cx3y2, j1Bx3, j1Ay2, cx3y2;
08:-:-:-:1  @P3 LDG.E.CI load1A0, [track1A + 4x<0>];
--:-:-:-:1      FFMA cx3y0, j1Bx3, j1Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j1Bx2, j1Ay0, cx2y0;
--:-:-:-:1  @P3 LDG.E.CI load1A1, [track1A + 4x<1>];
01:-:-:-:0      FFMA cx0y2, j2Bx0, j2Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j0Ay0, [readAs + 4x<8*128 + 00 + 2*8>];
--:-:-:-:0      FFMA cx1y2, j2Bx1, j2Ay2, cx1y2;
--:-:-:-:1  @P3 LDG.E.CI load1A2, [track1A + 4x<2>];
--:-:-:-:0      FFMA cx1y0, j2Bx1, j2Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j0Bx0, [readBs + 4x<8*32  + 00 + 0*8>];
--:-:-:-:0      FFMA cx0y0, j2Bx0, j2Ay0, cx0y0;
--:-:4:-:1  @P3 LDG.E.CI load1A3, [track1A + 4x<3>];
--:-:-:-:0      FFMA cx0y3, j2Bx0, j2Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j0Ay4, [readAs + 4x<8*128 + 64 + 2*8>];
--:-:-:-:1      FFMA cx1y3, j2Bx1, j2Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j2Bx1, j2Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j2Bx0, j2Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j2Bx0, j2Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j2Bx1, j2Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j2Bx1, j2Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j2Bx0, j2Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j2Bx0, j2Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j2Bx1, j2Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j2Bx1, j2Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j2Bx0, j2Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j2Bx2, j2Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j2Bx3, j2Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j2Bx3, j2Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j2Bx2, j2Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j2Bx2, j2Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j2Bx3, j2Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j2Bx3, j2Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j2Bx2, j2Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j2Bx2, j2Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j2Bx3, j2Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j2Bx3, j2Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j2Bx2, j2Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j2Bx2, j2Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j2Bx3, j2Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j2Bx3, j2Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j2Bx2, j2Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j3Bx0, j3Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j1Ay0, [readAs + 4x<9*128 + 00 + 2*8>];
--:-:-:-:1      FFMA cx1y2, j3Bx1, j3Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j3Bx1, j3Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j1Bx0, [readBs + 4x<9*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j3Bx0, j3Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j3Bx0, j3Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j1Ay4, [readAs + 4x<9*128 + 64 + 2*8>];
--:-:-:-:1      FFMA cx1y3, j3Bx1, j3Ay3, cx1y3;
--:-:-:-:0      FFMA cx1y1, j3Bx1, j3Ay1, cx1y1;
10:-:-:-:1  @P0 STS [writeAs + 4x<0*128 + 2*32>], load2A0;
--:-:-:-:1      FFMA cx0y1, j3Bx0, j3Ay1, cx0y1;
--:-:-:-:1  @P4 IADD   track2A0.CC, track2A0, 4x<16>;
--:-:-:-:0      FFMA cx0y6, j3Bx0, j3Ay6, cx0y6;
--:-:-:-:1  @P0 STS [writeAs + 4x<1*128 + 2*32>], load2A1;
--:-:-:-:1      FFMA cx1y6, j3Bx1, j3Ay6, cx1y6;
--:-:-:-:0      FFMA cx1y4, j3Bx1, j3Ay4, cx1y4;
--:-:-:-:1  @P0 STS [writeAs + 4x<2*128 + 2*32>], load2A2;
--:-:-:-:1      FFMA cx0y4, j3Bx0, j3Ay4, cx0y4;
--:-:-:-:0      FFMA cx0y7, j3Bx0, j3Ay7, cx0y7;
--:-:-:-:1  @P0 STS [writeAs + 4x<3*128 + 2*32>], load2A3;
--:-:-:-:1      FFMA cx1y7, j3Bx1, j3Ay7, cx1y7;
--:-:-:-:1  @P4 IADD.X track2A1,    track2A1, RZ;
--:-:-:-:1      FFMA cx1y5, j3Bx1, j3Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P4, PT, k, 32, P4;
--:-:-:-:1      FFMA cx0y5, j3Bx0, j3Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j3Bx2, j3Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j3Bx3, j3Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j3Bx3, j3Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j3Bx2, j3Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j3Bx2, j3Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j3Bx3, j3Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j3Bx3, j3Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j3Bx2, j3Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j3Bx2, j3Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j3Bx3, j3Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j3Bx3, j3Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j3Bx2, j3Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j3Bx2, j3Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j3Bx3, j3Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j3Bx3, j3Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j3Bx2, j3Ay0, cx2y0;
01:-:-:-:0      FFMA cx0y2, j0Bx0, j0Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j2Ay0, [readAs + 4x<10*128 + 00 + 2*8>];
--:-:-:-:1      FFMA cx1y2, j0Bx1, j0Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j0Bx1, j0Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j2Bx0, [readBs + 4x<10*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j0Bx0, j0Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j0Bx0, j0Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j2Ay4, [readAs + 4x<10*128 + 64 + 2*8>];
--:-:-:-:1      FFMA cx1y3, j0Bx1, j0Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j0Bx1, j0Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j0Bx0, j0Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j0Bx0, j0Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j0Bx1, j0Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j0Bx1, j0Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j0Bx0, j0Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j0Bx0, j0Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j0Bx1, j0Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j0Bx1, j0Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j0Bx0, j0Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j0Bx2, j0Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j0Bx3, j0Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j0Bx3, j0Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j0Bx2, j0Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j0Bx2, j0Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j0Bx3, j0Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j0Bx3, j0Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j0Bx2, j0Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j0Bx2, j0Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j0Bx3, j0Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j0Bx3, j0Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j0Bx2, j0Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j0Bx2, j0Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j0Bx3, j0Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j0Bx3, j0Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j0Bx2, j0Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j1Bx0, j1Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j3Ay0, [readAs + 4x<11*128 + 00 + 2*8>];
--:-:-:-:1      FFMA cx1y2, j1Bx1, j1Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j1Bx1, j1Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j3Bx0, [readBs + 4x<11*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j1Bx0, j1Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j1Bx0, j1Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j3Ay4, [readAs + 4x<11*128 + 64 + 2*8>];
--:-:-:-:1      FFMA cx1y3, j1Bx1, j1Ay3, cx1y3;
--:-:-:-:0      FFMA cx1y1, j1Bx1, j1Ay1, cx1y1;
--:-:-:-:1  @P0 STS [writeAs + 4x<0*128 + 3*32>], load3A0;
--:-:-:-:1      FFMA cx0y1, j1Bx0, j1Ay1, cx0y1;
--:-:-:-:1  @P5 IADD   track3A0.CC, track3A0, 4x<16>;
--:-:-:-:0      FFMA cx0y6, j1Bx0, j1Ay6, cx0y6;
--:-:-:-:1  @P0 STS [writeAs + 4x<1*128 + 3*32>], load3A1;
--:-:-:-:1      FFMA cx1y6, j1Bx1, j1Ay6, cx1y6;
--:-:-:-:0      FFMA cx1y4, j1Bx1, j1Ay4, cx1y4;
--:-:-:-:1  @P0 STS [writeAs + 4x<2*128 + 3*32>], load3A2;
--:-:-:-:1      FFMA cx0y4, j1Bx0, j1Ay4, cx0y4;
--:-:-:-:0      FFMA cx0y7, j1Bx0, j1Ay7, cx0y7;
--:5:-:-:1  @P0 STS [writeAs + 4x<3*128 + 3*32>], load3A3;
--:-:-:-:1      FFMA cx1y7, j1Bx1, j1Ay7, cx1y7;
--:-:-:-:1  @P5 IADD.X track3A1,    track3A1, RZ;
--:-:-:-:1      FFMA cx1y5, j1Bx1, j1Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P5, PT, k, 32, P5;
--:-:-:-:1      FFMA cx0y5, j1Bx0, j1Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j1Bx2, j1Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j1Bx3, j1Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j1Bx3, j1Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j1Bx2, j1Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j1Bx2, j1Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j1Bx3, j1Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j1Bx3, j1Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j1Bx2, j1Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j1Bx2, j1Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j1Bx3, j1Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j1Bx3, j1Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j1Bx2, j1Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j1Bx2, j1Ay2, cx2y2;
--:-:-:-:0      FFMA cx3y2, j1Bx3, j1Ay2, cx3y2;
10:-:-:-:1  @P4 LDG.E.CI load2A0, [track2A + 4x<0>];
--:-:-:-:1      FFMA cx3y0, j1Bx3, j1Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j1Bx2, j1Ay0, cx2y0;
--:-:-:-:1  @P4 LDG.E.CI load2A1, [track2A + 4x<1>];
01:-:-:-:0      FFMA cx0y2, j2Bx0, j2Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j0Ay0, [readAs + 4x<12*128 + 00 + 3*8>];
--:-:-:-:0      FFMA cx1y2, j2Bx1, j2Ay2, cx1y2;
--:-:-:-:1  @P4 LDG.E.CI load2A2, [track2A + 4x<2>];
--:-:-:-:0      FFMA cx1y0, j2Bx1, j2Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j0Bx0, [readBs + 4x<12*32  + 00 + 0*8>];
--:-:-:-:0      FFMA cx0y0, j2Bx0, j2Ay0, cx0y0;
--:-:5:-:1  @P4 LDG.E.CI load2A3, [track2A + 4x<3>];
--:-:-:-:0      FFMA cx0y3, j2Bx0, j2Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j0Ay4, [readAs + 4x<12*128 + 64 + 3*8>];
--:-:-:-:1      FFMA cx1y3, j2Bx1, j2Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j2Bx1, j2Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j2Bx0, j2Ay1, cx0y1;
--:-:-:-:0      FFMA cx0y6, j2Bx0, j2Ay6, cx0y6;
--:-:-:-:1  @P5 LDG.E.CI load3A0, [track3A + 4x<0>];
--:-:-:-:1      FFMA cx1y6, j2Bx1, j2Ay6, cx1y6;
--:-:-:-:0      FFMA cx1y4, j2Bx1, j2Ay4, cx1y4;
--:-:-:-:1  @P5 LDG.E.CI load3A1, [track3A + 4x<1>];
--:-:-:-:1      FFMA cx0y4, j2Bx0, j2Ay4, cx0y4;
--:-:-:-:0      FFMA cx0y7, j2Bx0, j2Ay7, cx0y7;
--:-:-:-:1  @P5 LDG.E.CI load3A2, [track3A + 4x<2>];
--:-:-:-:1      FFMA cx1y7, j2Bx1, j2Ay7, cx1y7;
--:-:-:-:0      FFMA cx1y5, j2Bx1, j2Ay5, cx1y5;
--:-:5:-:1  @P5 LDG.E.CI load3A3, [track3A + 4x<3>];
--:-:-:-:1      FFMA cx0y5, j2Bx0, j2Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j2Bx2, j2Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j2Bx3, j2Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j2Bx3, j2Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j2Bx2, j2Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j2Bx2, j2Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j2Bx3, j2Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j2Bx3, j2Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j2Bx2, j2Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j2Bx2, j2Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j2Bx3, j2Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j2Bx3, j2Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j2Bx2, j2Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j2Bx2, j2Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j2Bx3, j2Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j2Bx3, j2Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j2Bx2, j2Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j3Bx0, j3Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j1Ay0, [readAs + 4x<13*128 + 00 + 3*8>];
--:-:-:-:1      FFMA cx1y2, j3Bx1, j3Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j3Bx1, j3Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j1Bx0, [readBs + 4x<13*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j3Bx0, j3Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j3Bx0, j3Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j1Ay4, [readAs + 4x<13*128 + 64 + 3*8>];
--:-:-:-:1      FFMA cx1y3, j3Bx1, j3Ay3, cx1y3;
--:-:-:-:0      FFMA cx1y1, j3Bx1, j3Ay1, cx1y1;
20:6:-:-:1  @P0 STS.128 [writeBs], loadB;
--:-:-:-:1      FFMA cx0y1, j3Bx0, j3Ay1, cx0y1;
--:-:-:-:1  @P6 IADD   trackB0.CC,  trackB0,  ldb16;
--:-:-:-:1      FFMA cx0y6, j3Bx0, j3Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j3Bx1, j3Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j3Bx1, j3Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j3Bx0, j3Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j3Bx0, j3Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j3Bx1, j3Ay7, cx1y7;
--:-:-:-:1  @P6 IADD.X trackB1,     trackB1,  RZ;
--:-:-:-:1      FFMA cx1y5, j3Bx1, j3Ay5, cx1y5;
--:-:-:-:1      ISETP.GE.AND P6, PT, k, 32, P6;
--:-:-:-:1      FFMA cx0y5, j3Bx0, j3Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j3Bx2, j3Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j3Bx3, j3Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j3Bx3, j3Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j3Bx2, j3Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j3Bx2, j3Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j3Bx3, j3Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j3Bx3, j3Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j3Bx2, j3Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j3Bx2, j3Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j3Bx3, j3Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j3Bx3, j3Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j3Bx2, j3Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j3Bx2, j3Ay2, cx2y2;
--:-:-:-:0      FFMA cx3y2, j3Bx3, j3Ay2, cx3y2;
20:-:-:-:1  @P6 LDG.E.CI loadB0, [trackB + 4x<0>];
--:-:-:-:1      FFMA cx3y0, j3Bx3, j3Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j3Bx2, j3Ay0, cx2y0;
--:-:-:-:1  @P6 LDG.E.CI loadB1, [trackB + 4x<1>];
01:-:-:-:0      FFMA cx0y2, j0Bx0, j0Ay2, cx0y2;
--:-:1:-:1      LDS.U.128 j2Ay0, [readAs + 4x<14*128 + 00 + 3*8>];
--:-:-:-:0      FFMA cx1y2, j0Bx1, j0Ay2, cx1y2;
--:-:-:-:1  @P6 LDG.E.CI loadB2, [trackB + 4x<2>];
--:-:-:-:0      FFMA cx1y0, j0Bx1, j0Ay0, cx1y0;
--:-:1:-:1      LDS.U.128 j2Bx0, [readBs + 4x<14*32  + 00 + 0*8>];
--:-:-:-:0      FFMA cx0y0, j0Bx0, j0Ay0, cx0y0;
--:-:6:-:1  @P6 LDG.E.CI loadB3, [trackB + 4x<3>];
--:-:-:-:0      FFMA cx0y3, j0Bx0, j0Ay3, cx0y3;
--:-:1:-:1      LDS.U.128 j2Ay4, [readAs + 4x<14*128 + 64 + 3*8>];
--:-:-:-:1      FFMA cx1y3, j0Bx1, j0Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j0Bx1, j0Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j0Bx0, j0Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j0Bx0, j0Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j0Bx1, j0Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j0Bx1, j0Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j0Bx0, j0Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j0Bx0, j0Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j0Bx1, j0Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j0Bx1, j0Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j0Bx0, j0Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j0Bx2, j0Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j0Bx3, j0Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j0Bx3, j0Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j0Bx2, j0Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j0Bx2, j0Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j0Bx3, j0Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j0Bx3, j0Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j0Bx2, j0Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j0Bx2, j0Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j0Bx3, j0Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j0Bx3, j0Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j0Bx2, j0Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j0Bx2, j0Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j0Bx3, j0Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j0Bx3, j0Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j0Bx2, j0Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j1Bx0, j1Ay2, cx0y2;
--:-:2:-:1      LDS.U.128 j3Ay0, [readAs + 4x<15*128 + 00 + 3*8>];
--:-:-:-:1      FFMA cx1y2, j1Bx1, j1Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j1Bx1, j1Ay0, cx1y0;
--:-:2:-:1      LDS.U.128 j3Bx0, [readBs + 4x<15*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j1Bx0, j1Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j1Bx0, j1Ay3, cx0y3;
--:-:2:-:1      LDS.U.128 j3Ay4, [readAs + 4x<15*128 + 64 + 3*8>];
--:-:-:-:1      FFMA cx1y3, j1Bx1, j1Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j1Bx1, j1Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j1Bx0, j1Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j1Bx0, j1Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j1Bx1, j1Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j1Bx1, j1Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j1Bx0, j1Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j1Bx0, j1Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j1Bx1, j1Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j1Bx1, j1Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j1Bx0, j1Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j1Bx2, j1Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j1Bx3, j1Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j1Bx3, j1Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j1Bx2, j1Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j1Bx2, j1Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j1Bx3, j1Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j1Bx3, j1Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j1Bx2, j1Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j1Bx2, j1Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j1Bx3, j1Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j1Bx3, j1Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j1Bx2, j1Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j1Bx2, j1Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j1Bx3, j1Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j1Bx3, j1Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j1Bx2, j1Ay0, cx2y0;
--:-:-:-:5  @P0 BAR.SYNC 0;
--:-:-:-:1  @P0 IADD readAs,  readAs, -swapBuf;
--:-:-:-:1  @P0 IADD readBs,  readBs, -swapBuf;
--:-:-:-:1  @P0 IADD writeAs, writeAs, swapBuf;
--:-:-:-:1  @P0 IADD writeBs, writeBs, swapBuf;
--:-:-:-:1  @P0 IADD swapBuf, RZ,     -swapBuf;
01:-:-:-:0      FFMA cx0y2, j2Bx0, j2Ay2, cx0y2;
--:-:1:-:1  @P0 LDS.U.128 j0Ay0, [readAs + 4x<0*128 + 00 + 0*8>];
--:-:-:-:1      FFMA cx1y2, j2Bx1, j2Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j2Bx1, j2Ay0, cx1y0;
--:-:1:-:1  @P0 LDS.U.128 j0Bx0, [readBs + 4x<0*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j2Bx0, j2Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j2Bx0, j2Ay3, cx0y3;
--:-:1:-:1  @P0 LDS.U.128 j0Ay4, [readAs + 4x<0*128 + 64 + 0*8>];
--:-:-:-:1      FFMA cx1y3, j2Bx1, j2Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j2Bx1, j2Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j2Bx0, j2Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j2Bx0, j2Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j2Bx1, j2Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j2Bx1, j2Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j2Bx0, j2Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j2Bx0, j2Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j2Bx1, j2Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j2Bx1, j2Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j2Bx0, j2Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j2Bx2, j2Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j2Bx3, j2Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j2Bx3, j2Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j2Bx2, j2Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j2Bx2, j2Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j2Bx3, j2Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j2Bx3, j2Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j2Bx2, j2Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j2Bx2, j2Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j2Bx3, j2Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j2Bx3, j2Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j2Bx2, j2Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j2Bx2, j2Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j2Bx3, j2Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j2Bx3, j2Ay0, cx3y0;
--:-:-:-:1      FFMA cx2y0, j2Bx2, j2Ay0, cx2y0;
02:-:-:-:0      FFMA cx0y2, j3Bx0, j3Ay2, cx0y2;
--:-:2:-:1  @P0 LDS.U.128 j1Ay0, [readAs + 4x<1*128 + 00 + 0*8>];
--:-:-:-:1      FFMA cx1y2, j3Bx1, j3Ay2, cx1y2;
--:-:-:-:0      FFMA cx1y0, j3Bx1, j3Ay0, cx1y0;
--:-:2:-:1  @P0 LDS.U.128 j1Bx0, [readBs + 4x<1*32  + 00 + 0*8>];
--:-:-:-:1      FFMA cx0y0, j3Bx0, j3Ay0, cx0y0;
--:-:-:-:0      FFMA cx0y3, j3Bx0, j3Ay3, cx0y3;
--:-:2:-:1  @P0 LDS.U.128 j1Ay4, [readAs + 4x<1*128 + 64 + 0*8>];
--:-:-:-:1      FFMA cx1y3, j3Bx1, j3Ay3, cx1y3;
--:-:-:-:1      FFMA cx1y1, j3Bx1, j3Ay1, cx1y1;
--:-:-:-:1      FFMA cx0y1, j3Bx0, j3Ay1, cx0y1;
--:-:-:-:1      FFMA cx0y6, j3Bx0, j3Ay6, cx0y6;
--:-:-:-:1      FFMA cx1y6, j3Bx1, j3Ay6, cx1y6;
--:-:-:-:1      FFMA cx1y4, j3Bx1, j3Ay4, cx1y4;
--:-:-:-:1      FFMA cx0y4, j3Bx0, j3Ay4, cx0y4;
--:-:-:-:1      FFMA cx0y7, j3Bx0, j3Ay7, cx0y7;
--:-:-:-:1      FFMA cx1y7, j3Bx1, j3Ay7, cx1y7;
--:-:-:-:1      FFMA cx1y5, j3Bx1, j3Ay5, cx1y5;
--:-:-:-:1      FFMA cx0y5, j3Bx0, j3Ay5, cx0y5;
--:-:-:Y:1      FFMA cx2y7, j3Bx2, j3Ay7, cx2y7;
--:-:-:-:1      FFMA cx3y7, j3Bx3, j3Ay7, cx3y7;
--:-:-:-:1      FFMA cx3y5, j3Bx3, j3Ay5, cx3y5;
--:-:-:-:1      FFMA cx2y5, j3Bx2, j3Ay5, cx2y5;
--:-:-:-:1      FFMA cx2y6, j3Bx2, j3Ay6, cx2y6;
--:-:-:-:1      FFMA cx3y6, j3Bx3, j3Ay6, cx3y6;
--:-:-:-:1      FFMA cx3y4, j3Bx3, j3Ay4, cx3y4;
--:-:-:-:1      FFMA cx2y4, j3Bx2, j3Ay4, cx2y4;
--:-:-:-:1      FFMA cx2y3, j3Bx2, j3Ay3, cx2y3;
--:-:-:-:1      FFMA cx3y3, j3Bx3, j3Ay3, cx3y3;
--:-:-:-:1      FFMA cx3y1, j3Bx3, j3Ay1, cx3y1;
--:-:-:-:1      FFMA cx2y1, j3Bx2, j3Ay1, cx2y1;
--:-:-:-:1      FFMA cx2y2, j3Bx2, j3Ay2, cx2y2;
--:-:-:-:1      FFMA cx3y2, j3Bx3, j3Ay2, cx3y2;
--:-:-:-:1      FFMA cx3y0, j3Bx3, j3Ay0, cx3y0;
--:-:-:-:0      FFMA cx2y0, j3Bx2, j3Ay0, cx2y0;
--:-:-:Y:5  @P0 BRA.U LOOP;
--:-:-:Y:5  @P1 BRA.U REMAINDER;

--:-:-:-:1      LOP.AND tid31, tid, 31;
--:-:-:-:1      ISETP.GT.AND P0, PT, swapBuf, RZ, PT;
--:-:-:-:1      LOP.AND tid96, tid, 96;
--:-:-:-:1      MOV ldc, c[0x0][0x16c];
--:-:-:-:1      MOV ldcz, c[0x0][0x184]; //ldcz=0
--:-:-:-:1      IADD readBs, readBs, -4x<(128*16 + 32)>;
--:-:-:-:1      ISCADD cx, blkB, tid31, 5;
--:-:-:-:1      MOV beta, c[0x0][0x15c];
--:-:-:-:1      SHR.U32 cy00, tid96, 1;
--:-:-:-:1      MOV flags, c[0x0][0x160];
--:-:-:-:1      ISCADD readCs, tid96, tid31, 2;
--:-:-:-:1      MOV alpha, c[0x0][0x158];
--:-:-:-:1      ISETP.LT.AND P6, PT, cx, c[0x0][0x174], PT;
--:-:-:-:1      SHL ldc4, ldc, 4;
--:-:-:-:1  @P0 IADD readAs, readAs, -swapBuf;
--:-:-:-:1      ISCADD cy00, blkA, cy00, 7;
--:-:-:-:1  @P0 IADD readBs, readBs, -swapBuf;
--:-:-:-:1      SHL readCs, readCs, 2;
--:-:-:-:1      LOP.AND.NZ P4, RZ, flags, 2;
--:-:-:-:2      SHL ldc1, ldc, 2;
--:-:-:-:1      XMAD.MRG xmad_c, ldc, cy00.H1, RZ;
--:-:-:-:1      ISCADD writeCs, readAs, readBs, 3;
--:-:-:-:1      XMAD ci, ldc, cy00, cx;
--:-:-:-:1      ISCADD ldc60, ldc, -ldc4, 8;
--:-:-:-:4      ISETP.NE.AND P5, PT, beta, RZ, P6; 
--:-:-:Y:6      XMAD.PSL.CBCC ci, ldc.H1, xmad_c.H1, ci;
--:-:-:Y:6      XMAD ci, ldcz, blkZ, ci;
--:-:-:Y:6      XMAD.PSL ci, ldcz.H1, blkZ, ci;
--:-:-:-:2      LEA C00y0.CC, ci, c[0x0][0x140], 2;
--:-:-:-:1      LEA.HI.X C00y1, ci, c[0x0][0x144], RZ, 2;

--:-:-:-:4      IADD   C04y0.CC, C00y0, ldc4;
--:-:-:-:1      MOV d0, RZ;
--:-:-:-:1      IADD   cy04, cy00,  4;
--:-:-:-:1      IADD.X C04y1,    C00y1, RZ;
--:-:-:-:4      IADD   C08y0.CC, C04y0, ldc4;
--:-:-:-:1      MOV d1, RZ;
--:-:-:-:1      IADD   cy08, cy00,  8;
--:-:-:-:1      IADD.X C08y1,    C04y1, RZ;
--:-:-:-:3      IADD   C12y0.CC, C08y0, ldc4;
--:-:-:-:1      MOV d2, RZ;
--:-:-:-:1      MOV d3, RZ;
--:-:-:-:1      IADD   cy12, cy00,  12;
--:-:-:-:0      IADD.X C12y1,    C08y1, RZ;

--:-:-:-:5      BAR.SYNC 0;

--:-:-:-:1      FMUL c0, cx0y0, alpha;
--:-:-:-:1      FMUL c1, cx1y0, alpha;
--:-:-:-:1      FMUL c2, cx2y0, alpha;
--:-:-:-:0      FMUL c3, cx3y0, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y1, alpha;
--:-:-:-:1      FMUL c1, cx1y1, alpha;
--:-:-:-:1      FMUL c2, cx2y1, alpha;
--:-:-:-:0      FMUL c3, cx3y1, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y2, alpha;
--:-:-:-:1      FMUL c1, cx1y2, alpha;
--:-:-:-:1      FMUL c2, cx2y2, alpha;
--:-:-:-:0      FMUL c3, cx3y2, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y3, alpha;
--:-:-:-:1      FMUL c1, cx1y3, alpha;
--:-:-:-:1      FMUL c2, cx2y3, alpha;
--:-:-:-:0      FMUL c3, cx3y3, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:5      IADD   C00y0.CC, C00y0, ldc60;
--:-:-:-:1      IADD   cy00,     cy00,  60;
--:-:-:-:1      IADD.X C00y1,    C00y1, RZ;
--:-:-:-:5      IADD   C04y0.CC, C04y0, ldc60;
--:-:-:-:1      IADD   cy04,     cy04,  60;
--:-:-:-:1      IADD.X C04y1,    C04y1, RZ;
--:-:-:-:5      IADD   C08y0.CC, C08y0, ldc60;
--:-:-:-:1      IADD   cy08,     cy08,  60;
--:-:-:-:1      IADD.X C08y1,    C08y1, RZ;
--:-:-:-:5      IADD   C12y0.CC, C12y0, ldc60;
--:-:-:-:1      IADD   cy12,     cy12,  60;
--:-:-:-:1      IADD.X C12y1,    C12y1, RZ;

--:-:-:-:1      FMUL c0, cx0y4, alpha;
--:-:-:-:1      FMUL c1, cx1y4, alpha;
--:-:-:-:1      FMUL c2, cx2y4, alpha;
--:-:-:-:0      FMUL c3, cx3y4, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y5, alpha;
--:-:-:-:1      FMUL c1, cx1y5, alpha;
--:-:-:-:1      FMUL c2, cx2y5, alpha;
--:-:-:-:0      FMUL c3, cx3y5, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y6, alpha;
--:-:-:-:1      FMUL c1, cx1y6, alpha;
--:-:-:-:1      FMUL c2, cx2y6, alpha;
--:-:-:-:0      FMUL c3, cx3y6, alpha;
--:-:-:-:5      CAL STORE_C;

--:-:-:-:1      FMUL c0, cx0y7, alpha;
--:-:-:-:1      FMUL c1, cx1y7, alpha;
--:-:-:-:1      FMUL c2, cx2y7, alpha;
--:-:-:-:0      FMUL c3, cx3y7, alpha;
--:-:-:-:5      CAL STORE_C;


--:-:-:-:5      EXIT;

STORE_C:

--:-:-:-:1      ISETP.LT.AND P0, PT, cy00, c[0x0][0x170], P5;
--:-:-:-:1  @P4 FMNMX c0, c0, RZ, !PT;
--:-:-:-:1      ISETP.LT.AND P1, PT, cy04, c[0x0][0x170], P5;
--:-:-:-:1  @P4 FMNMX c1, c1, RZ, !PT;
--:-:-:-:1      ISETP.LT.AND P2, PT, cy08, c[0x0][0x170], P5;
--:-:-:-:1  @P4 FMNMX c2, c2, RZ, !PT;
--:-:-:-:1      ISETP.LT.AND P3, PT, cy12, c[0x0][0x170], P5;
--:-:-:-:4  @P4 FMNMX c3, c3, RZ, !PT;
--:-:-:-:1      STS.128 [writeCs], c0;
--:-:-:-:1      LDS c0, [readCs + 4x<0*32>];
--:-:-:-:0 @!P0 MOV d0, RZ;
--:-:1:-:1  @P0 LDG.E d0, [C00y];
--:-:-:-:0      ISETP.LT.AND P0, PT, cy00, c[0x0][0x170], P6;
--:-:5:-:1      LDS c1, [readCs + 4x<1*32>];
--:-:-:-:0 @!P1 MOV d1, RZ;
--:-:2:-:1  @P1 LDG.E d1, [C04y];
--:-:-:-:0      ISETP.LT.AND P1, PT, cy04, c[0x0][0x170], P6;
--:-:-:-:1      LDS c2, [readCs + 4x<2*32>];
--:-:-:-:0 @!P2 MOV d2, RZ;
--:-:3:-:1  @P2 LDG.E d2, [C08y];
--:-:-:-:0      ISETP.LT.AND P2, PT, cy08, c[0x0][0x170], P6;
--:-:6:-:1      LDS c3, [readCs + 4x<3*32>];
--:-:-:-:0 @!P3 MOV d3, RZ;
--:-:4:-:1  @P3 LDG.E d3, [C12y];
--:-:-:-:1      ISETP.LT.AND P3, PT, cy12, c[0x0][0x170], P6;
--:-:-:-:1      IADD cy00, cy00, 1;
--:-:-:-:1      IADD cy04, cy04, 1;
--:-:-:-:1      IADD cy08, cy08, 1;
--:-:-:-:3      IADD cy12, cy12, 1;

11:-:-:-:1  @P5 FFMA c0, d0, beta, c0;
02:-:-:-:1  @P5 FFMA c1, d1, beta, c1;
24:-:-:-:1  @P5 FFMA c2, d2, beta, c2;
08:-:-:-:0  @P5 FFMA c3, d3, beta, c3;

--:1:-:-:1  @P0 STG.E.CG [C00y], c0;
--:2:-:-:1  @P1 STG.E.CG [C04y], c1;
--:3:-:-:1  @P2 STG.E.CG [C08y], c2;
--:4:-:-:1  @P3 STG.E.CG [C12y], c3;

01:-:-:-:6      IADD   C00y0.CC, C00y0, ldc1;
--:-:-:-:1      IADD.X C00y1,    C00y1, RZ;
02:-:-:-:6      IADD   C04y0.CC, C04y0, ldc1;
--:-:-:-:1      IADD.X C04y1,    C04y1, RZ;
04:-:-:-:6      IADD   C08y0.CC, C08y0, ldc1;
--:-:-:-:1      IADD.X C08y1,    C08y1, RZ;
08:-:-:-:6      IADD   C12y0.CC, C12y0, ldc1;
--:-:-:-:0      IADD.X C12y1,    C12y1, RZ;

--:-:-:-:5      RET;