extends CanvasLayer

@onready var question_label: Label = $PanelContainer/MarginContainer/VBoxContainer/QuestionLabel
@onready var line_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/LineEdit
@onready var submit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SubmitButton
@onready var feedback_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FeedbackLabel

var correct_answers: Array[String] = []
var current_question: String = ""
var npc_role: String = "Rion, teman alien yang suportif dan lucu"

signal challenge_completed(is_correct: bool)

func _ready() -> void:
	hide()
	submit_button.pressed.connect(_on_submit)
	# Pakai signal answer_checked yang punya konteks soal
	AIManager.answer_checked.connect(_on_ai_response)

func start(question: String, answers: Array[String]) -> void:
	correct_answers = answers
	current_question = question  # Simpan pertanyaan untuk dikirim ke AI
	question_label.text = question
	line_edit.text = ""
	feedback_label.text = ""
	line_edit.grab_focus()
	show()

func _on_submit() -> void:
	var input = line_edit.text.strip_edges()
	if input.is_empty():
		return

	submit_button.disabled = true  # Cegah double submit saat menunggu AI

	var is_correct = NLPManager.validate(input, correct_answers)

	if is_correct:
		feedback_label.text = "Wah keren! Rion sedang merespons..."
	else:
		feedback_label.text = "Hmm, Rion akan bantu kamu..."

	# Kirim ke AI dengan konteks pertanyaan + jawaban + status benar/salah
	AIManager.check_answer(current_question, input, is_correct, npc_role)

	challenge_completed.emit(is_correct)

func _on_ai_response(reply: String) -> void:
	submit_button.disabled = false
	hide()
	StoryManager.start_dialogue([reply], "Rion")
