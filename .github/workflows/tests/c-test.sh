printf "atcg" > test1.txt 
printf "atcgtc" > test2.txt 
printf "atcg" > result.txt 
./lcs test1.txt test2.txt 5 out.txt
diff result.txt out.txt >> countLine
counter=$(wc -l < countLine)
if [ "$counter" -ne 0 ]; then echo "Error"; fi
#in case other tests are added substitute 0 with the number of expected line (one per failed test)
