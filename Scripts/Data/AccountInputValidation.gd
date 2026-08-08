extends RefCounted
class_name AccountInputValidation

## 客户端只负责即时格式反馈；敏感词、唯一性和最终可用性始终由服务端决定。

static func username_error_key(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.is_empty():
		return "ui.account.status.required"
	if candidate.length() < 2 or candidate.length() > 20:
		return "ui.account.status.id_length"
	for index in range(candidate.length()):
		var code := candidate.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code == 95
			or (code >= 0x3400 and code <= 0x4DBF)
			or (code >= 0x4E00 and code <= 0x9FFF)
		)
		if not allowed:
			return "ui.account.status.id_format"
	return ""

static func email_error_key(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.is_empty():
		return "ui.account.status.required"
	var email_pattern := RegEx.new()
	email_pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	if candidate.length() > 100 or email_pattern.search(candidate) == null:
		return "ui.account.status.email_format"
	return ""

static func password_error_key(value: String) -> String:
	if value.is_empty():
		return "ui.account.status.required"
	if value.length() < 6 or value.length() > 50:
		return "ui.account.status.password_length"
	return ""
