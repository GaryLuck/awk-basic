10 REM String variable tests
20 LET A$ = "Hello"
30 LET B$ = "World"
40 PRINT "Test 1 - Basic string print:"
50 PRINT A$
60 PRINT "Test 2 - String vars in same PRINT:"
70 PRINT A$; " "; B$
80 PRINT "Test 3 - Copy string var:"
90 LET C$ = A$
100 PRINT C$
110 PRINT "Test 4 - Mixed string and numeric:"
120 LET X = 42
130 PRINT "The answer is "; X
140 PRINT "Test 5 - INPUT a string:"
150 INPUT "Enter your name: ", N$
160 PRINT "Hello, "; N$; "!"
170 PRINT "Test 6 - INPUT a number:"
180 INPUT "Enter a number: ", Y
190 PRINT "You entered: "; Y
200 PRINT "Done!"
210 END
