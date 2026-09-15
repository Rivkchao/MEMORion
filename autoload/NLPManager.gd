extends Node

# Levenshtein Distance
func levenshtein(a: String, b: String) -> int:
	var m = a.length()
	var n = b.length()
	var dp = []
	
	for i in range(m + 1):
		dp.append([])
		for j in range(n + 1):
			dp[i].append(0)
	
	for i in range(m + 1):
		dp[i][0] = i
	for j in range(n + 1):
		dp[0][j] = j
	
	for i in range(1, m + 1):
		for j in range(1, n + 1):
			if a[i-1] == b[j-1]:
				dp[i][j] = dp[i-1][j-1]
			else:
				dp[i][j] = 1 + min(dp[i-1][j], min(dp[i][j-1], dp[i-1][j-1]))
	
	return dp[m][n]

# Validasi jawaban dengan sinonim
func validate(player_input: String, correct_answers: Array[String]) -> bool:
	var input = player_input.strip_edges().to_lower()
	
	for answer in correct_answers:
		var target = answer.to_lower()
		var length = target.length()
		
		# Tentukan toleransi dinamis berdasarkan panjang kata
		var dynamic_tolerance = 1
		if length > 5:
			dynamic_tolerance = 2
		elif length <= 3:
			dynamic_tolerance = 0 # Kata 3 huruf harus persis sama, atau setidaknya 1 jika sangat darurat
			
		var dist = levenshtein(input, target)
		if dist <= dynamic_tolerance:
			return true
			
	return false
