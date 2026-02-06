10 REM Array test
20 DIM A(5)
30 LET I = 0
40 IF I > 4 THEN 80
50 LET A(I) = I * I
60 LET I = I + 1
70 GOTO 40
80 LET I = 0
90 IF I > 4 THEN 130
100 PRINT "A(", I, ") = ", A(I)
110 LET I = I + 1
120 GOTO 90
130 PRINT "Arithmetic: 3+4*2 = ", 3+4*2
140 PRINT "Arithmetic: (3+4)*2 = ", (3+4)*2
150 LET X = 100 / 7
160 PRINT "100 / 7 = ", X
170 IF 5 > 3 THEN PRINT "5 > 3 is TRUE"
180 IF 2 > 3 THEN PRINT "2 > 3 SHOULD NOT PRINT"
190 PRINT "All tests passed!"
200 END
