# Unique Test
#make test file
echo "atcg" > test1.txt 
echo "atcgtc" > test2.txt 
#make expected result file
echo "atcg" > result.txt 
# run alghorithm
./lcs test1.txt test2.txt 5 out.txt
#compare results
diff result.txt out.txt
