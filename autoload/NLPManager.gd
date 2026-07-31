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
func validate(player_input: String, correct_answers: Array[String], tolerance: int = 2) -> bool:
	var input = player_input.strip_edges().to_lower()
	
	for answer in correct_answers:
		var dist = levenshtein(input, answer.to_lower())
		if dist <= tolerance:
			return true
	
	return false
