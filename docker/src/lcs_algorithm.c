#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

#define MAX(a, b) (a > b ? a : b)
#define MIN(a, b) (a < b ? a : b)

char* readFile(FILE *fin, char *txt, int block_size) {
	fseek(fin, 0L, SEEK_END);
	int sz = ftell(fin);

	txt = (char*)malloc((sz+1) * sizeof(char));
	fseek(fin, 0L, SEEK_SET);

	(void)fscanf(fin, "%s", txt);

	return txt;
}

char* lcs (char *a, int n, char *b, int m, char *s, int block_size) {
    int i, j, k, t, l;
	int i_start, j_start;

	short *z = calloc((n + 1) * (m + 1), sizeof (short));
    short **c = calloc((n + 1), sizeof (short *));
    
	//Assign to variable c the pointers to the different rows of the matrix 
	for (i = 0; i <= n; i++) {
        c[i] = &z[i * (m + 1)];
    }

	for (k=1; k <= (m+n)/block_size - 1; k++){   	    		
		#pragma omp parallel for private(i,j, i_start, j_start)
		for (l=MAX(1,k-n/block_size+1); l <= MIN(m/block_size,k); l++){				
			
			i_start = 1+block_size*(k-l);				
			j_start = 1+block_size*(l-1);

			//Serial lcs algorithm to the block
			for (i = i_start; i < i_start+block_size; i++) {
				for (j = j_start; j < j_start+block_size; j++) {
		        				        	
					//Critic section isn't necessary since  matrix cells of same block in parallel are never accessed
					if (a[i - 1] == b[j - 1]) {			            	
		                c[i][j] = c[i - 1][j - 1] + 1;
		            }else {
		                c[i][j] = MAX(c[i - 1][j], c[i][j - 1]);
		            }
		        }
		    }				
		}				
	}

    t = c[n][m];
    s = (char*)malloc((t+1) * sizeof(char));;
    
	
	//Rebuild of the lcs string
    for (i = n, j = m, k = t - 1; k >= 0;) {
		if (a[i - 1] == b[j - 1]) {
			s[k] = a[i - 1];
			i--; j--; k--;
		}else if (c[i][j - 1] > c[i - 1][j]) {
			j--;
		}else {
			i--;
		}
    }

	s[t] = '\0';
	free(c);
    free(z);
	return s;
}

//Round the dimension of a string as multiple of the block size and add numeric characters that never appear in genetics strings into that string
void preproc_string(int n, int *tondo, int block_size, char *str, int par) {
	int i;

	if (n % block_size == 0) {
		tondo[0] = n;
	}else {
		tondo[0] = block_size * (n / block_size + 1);
	}

	for (i = n; i < tondo[0]; i++) {
		if (par == 1) {
			str[i] = '1';
		}else {
			str[i] = '2';
		}
	}
}

int main (int argc, char *argv[]) {
	char *a=NULL, *b=NULL, *s=NULL;
   	int n_tondo, m_tondo, block_size;
	FILE* fin1, * fin2, * result;

    if(argc != 5) { //file1.txt file2.txt matrix_block_size
		printf("\033[31;1m Wrong parameters! \033[0m\n");    	
		return -1;
	}	

	if ((fin1 = fopen(argv[1], "r")) == NULL || (fin2 = fopen(argv[2], "r")) == NULL) {
		printf("\033[31;1m Error in opening file1 or file2! \033[0m\n");
		return -1;
	}
	block_size = atoi(argv[3]);

	a = readFile(fin1, a, block_size);
	b = readFile(fin2, b, block_size);   
	
	preproc_string((int)strlen(a), &n_tondo, block_size, a, 1);
	preproc_string((int)strlen(b), &m_tondo, block_size, b, 2);
    printf("lcs\n");
    s=lcs(a, n_tondo, b, m_tondo, s, block_size);

	if ((result = fopen(argv[4], "w")) == NULL) {
		printf("\033[31;1m Error in opening result file! \033[0m\n");
		return -1;
	}
	fprintf(result, "%s", s);

	free(a);
	free(b);
	free(s);

	fclose(fin1);
	fclose(fin2);
	fclose(result);

	return 0;
}