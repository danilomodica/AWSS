# Unique Test
#make test file
printf "atcg" > test1.txt 
printf "atcgtc" > test2.txt 
#make expected result file
printf "atcg" > result.txt 
# run alghorithm
./lcs test1.txt test2.txt 5 out.txt
#compare results
diff result.txt out.txt
