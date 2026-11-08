extends Control
class_name DashboardGraph

enum GraphType {
	BAR,
	PIE,
	LINE,
	HORIZONTAL_BAR,
	PROGRESS,
	QUIZ_SECTION
}

@export var graph_type: GraphType = GraphType.BAR

var graph_labels: Array[String] = []
var graph_values: Array[float] = []
var graph_colors: Array[Color] = []
var line_series: Array[Dictionary] = []
var line_categories: Array[String] = []

var quiz_section_labels: Array[String] = []
var quiz_result_counts: Array[int] = []
var quiz_average_scores: Array[float] = []

const ELEMENTS_TOTAL: int = 118

# Content sizing
const QUIZ_ROW_HEIGHT := 80.0
const QUIZ_GRAPH_MIN_HEIGHT := 320.0
const SECTION_ROW_HEIGHT := 48.0
const SECTION_GRAPH_MIN_HEIGHT := 460.0
const ATOMON_ROW_HEIGHT := 120.0
const ATOMON_GRAPH_MIN_HEIGHT := 320.0

# All graph fonts use 25 px.
const AXIS_FONT_SIZE: int = 25
const BAR_VALUE_FONT_SIZE: int = 25
const CATEGORY_FONT_SIZE: int = 25
const PIE_LEGEND_FONT_SIZE: int = 25
const PIE_VALUE_FONT_SIZE: int = 25
const MESSAGE_FONT_SIZE: int = 25

const SECTION_AXIS_FONT_SIZE: int = 25
const SECTION_LABEL_FONT_SIZE: int = 25
const SECTION_VALUE_FONT_SIZE: int = 25

const QUIZ_LABEL_FONT_SIZE: int = 25
const QUIZ_VALUE_FONT_SIZE: int = 25
const QUIZ_HEADER_FONT_SIZE: int = 25

const ATOMON_LABEL_FONT_SIZE: int = 25
const ATOMON_VALUE_FONT_SIZE: int = 25

const TEXT_COLOR := Color("#4F3824")
const MUTED_COLOR := Color("#92775E")
const GRID_COLOR := Color("#EADCC7")
const TRACK_COLOR := Color("#EADCC7")
const PROGRESS_COLOR := Color("#7167F5")

const DEFAULT_COLORS: Array[Color] = [
	Color("#75A66A"),
	Color("#D99A36"),
	Color("#D98A75"),
	Color("#8CA8C7"),
	Color("#B49ACB"),
	Color("#E4BD6B"),
	Color("#77B7A8")
]


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _update_graph_content_height(
	item_count: int,
	row_height: float,
	min_height: float
) -> void:
	custom_minimum_size.y = maxf(
		min_height,
		32.0 + float(item_count) * row_height
	)
	queue_redraw()


# ------------------------------------------------------------
# DATA INPUT
# ------------------------------------------------------------

func set_graph_data(
	labels: Array[String],
	values: Array[float],
	colors: Array[Color] = []
) -> void:
	graph_labels = labels.duplicate()
	graph_values = values.duplicate()
	graph_colors = colors.duplicate()

	line_categories.clear()
	line_series.clear()

	match graph_type:
		GraphType.HORIZONTAL_BAR:
			_update_graph_content_height(
				graph_values.size(),
				SECTION_ROW_HEIGHT,
				SECTION_GRAPH_MIN_HEIGHT
			)

		GraphType.PROGRESS:
			_update_graph_content_height(
				graph_values.size(),
				ATOMON_ROW_HEIGHT,
				ATOMON_GRAPH_MIN_HEIGHT
			)

		_:
			queue_redraw()


func set_line_graph_data(
	categories: Array[String],
	series: Array[Dictionary]
) -> void:
	line_categories = categories.duplicate()
	line_series = series.duplicate(true)
	graph_labels = categories.duplicate()
	graph_values.clear()
	graph_colors.clear()

	for item in line_series:
		var values: Array = item.get("values", [])
		for value in values:
			graph_values.append(float(value))

	queue_redraw()


func set_quiz_section_data(
	section_labels: Array[String],
	result_counts: Array[int],
	average_scores: Array[float]
) -> void:
	quiz_section_labels = section_labels.duplicate()
	quiz_result_counts = result_counts.duplicate()
	quiz_average_scores = average_scores.duplicate()

	_update_graph_content_height(
		quiz_section_labels.size(),
		QUIZ_ROW_HEIGHT,
		QUIZ_GRAPH_MIN_HEIGHT
	)


# ------------------------------------------------------------
# DRAW ROUTER
# ------------------------------------------------------------

func _draw() -> void:
	if graph_type == GraphType.QUIZ_SECTION:
		_draw_quiz_section_graph()
		return

	if graph_type == GraphType.LINE:
		if line_categories.is_empty() or line_series.is_empty():
			_draw_message("No quiz score data available")
		else:
			_draw_line_graph()
		return

	if graph_values.is_empty():
		_draw_message("No data available")
		return

	match graph_type:
		GraphType.BAR:
			_draw_bar_graph()
		GraphType.PIE:
			_draw_pie_graph()
		GraphType.HORIZONTAL_BAR:
			_draw_horizontal_bar_graph()
		GraphType.PROGRESS:
			_draw_progress_bar()


# ------------------------------------------------------------
# SHARED HELPERS
# ------------------------------------------------------------

func _draw_message(message: String) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8.0, size.y * 0.5 + MESSAGE_FONT_SIZE * 0.35),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		maxf(size.x - 16.0, 0.0),
		MESSAGE_FONT_SIZE,
		MUTED_COLOR
	)


func _get_color(index: int) -> Color:
	if index < graph_colors.size():
		return graph_colors[index]
	return DEFAULT_COLORS[index % DEFAULT_COLORS.size()]


func _draw_grid_line(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, GRID_COLOR, 1.0)


# ------------------------------------------------------------
# VERTICAL BAR GRAPH
# ------------------------------------------------------------

func _draw_bar_graph() -> void:
	var count := graph_values.size()
	if count == 0:
		return

	var left := 65.0
	var right := 12.0
	var top := 25.0
	var bottom := 48.0
	var chart_width := size.x - left - right
	var chart_height := size.y - top - bottom

	if chart_width <= 0.0 or chart_height <= 0.0:
		return

	var maximum := 1.0
	for value in graph_values:
		maximum = maxf(maximum, maxf(value, 0.0))

	for step in range(5):
		var ratio := float(step) / 4.0
		var y := top + chart_height * (1.0 - ratio)
		_draw_grid_line(Vector2(left, y), Vector2(left + chart_width, y))

		draw_string(
			ThemeDB.fallback_font,
			Vector2(0.0, y + 8.0),
			str(int(round(maximum * ratio))),
			HORIZONTAL_ALIGNMENT_LEFT,
			left - 8.0,
			AXIS_FONT_SIZE,
			MUTED_COLOR
		)

	var slot := chart_width / float(count)
	var bar_width := minf(slot * 0.58, 48.0)

	for i in range(count):
		var value := maxf(graph_values[i], 0.0)
		var bar_height := chart_height * value / maximum
		var x := left + slot * i + (slot - bar_width) * 0.5
		var y := top + chart_height - bar_height

		if value > 0.0:
			draw_rect(Rect2(x, y, bar_width, bar_height), _get_color(i))

		draw_string(
			ThemeDB.fallback_font,
			Vector2(left + slot * i, maxf(y - 4.0, top + BAR_VALUE_FONT_SIZE)),
			str(int(round(value))),
			HORIZONTAL_ALIGNMENT_CENTER,
			slot,
			BAR_VALUE_FONT_SIZE,
			TEXT_COLOR
		)

		var label := graph_labels[i] if i < graph_labels.size() else str(i + 1)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(left + slot * i, top + chart_height + 30.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			slot,
			CATEGORY_FONT_SIZE,
			TEXT_COLOR
		)


# ------------------------------------------------------------
# STUDENT PER SECTION - HORIZONTAL BAR GRAPH
# ------------------------------------------------------------

func _draw_horizontal_bar_graph() -> void:
	var count := graph_values.size()
	if count == 0:
		return

	var left := minf(170.0, size.x * 0.34)
	var right := 48.0
	var top := 16.0
	var bottom := 38.0
	var chart_width := size.x - left - right
	var chart_height := size.y - top - bottom

	if chart_width <= 0.0 or chart_height <= 0.0:
		return

	var maximum := 1.0
	for value in graph_values:
		maximum = maxf(maximum, maxf(value, 0.0))

	var slot_height := chart_height / float(count)
	var bar_height := minf(slot_height * 0.58, 28.0)

	for step in range(5):
		var ratio := float(step) / 4.0
		var x := left + chart_width * ratio
		_draw_grid_line(Vector2(x, top), Vector2(x, top + chart_height))

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 20.0, top + chart_height + 28.0),
			str(int(round(maximum * ratio))),
			HORIZONTAL_ALIGNMENT_CENTER,
			40.0,
			SECTION_AXIS_FONT_SIZE,
			MUTED_COLOR
		)

	for i in range(count):
		var value := maxf(graph_values[i], 0.0)
		var y := top + slot_height * i + (slot_height - bar_height) * 0.5
		var bar_width := chart_width * value / maximum
		var label := graph_labels[i] if i < graph_labels.size() else str(i + 1)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(0.0, y + bar_height * 0.5 + SECTION_LABEL_FONT_SIZE * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			left - 12.0,
			SECTION_LABEL_FONT_SIZE,
			TEXT_COLOR
		)

		if value > 0.0:
			draw_rect(Rect2(left, y, bar_width, bar_height), _get_color(i))

		var value_x := minf(left + bar_width + 6.0, size.x - 42.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(value_x, y + bar_height * 0.5 + SECTION_VALUE_FONT_SIZE * 0.35),
			str(int(round(value))),
			HORIZONTAL_ALIGNMENT_LEFT,
			42.0,
			SECTION_VALUE_FONT_SIZE,
			TEXT_COLOR
		)


# ------------------------------------------------------------
# TOTAL USERS - PIE GRAPH
# Increased legend spacing to keep labels and values apart.
# ------------------------------------------------------------

func _draw_pie_graph() -> void:
	var total := 0.0
	for value in graph_values:
		total += maxf(value, 0.0)

	if total <= 0.0:
		_draw_message("No user data available")
		return

	if size.x < 220.0 or size.y < 160.0:
		_draw_message("Waiting for chart area")
		return

	var legend_width := minf(size.x * 0.42, 205.0)
	var pie_width := size.x - legend_width - 18.0
	var radius := minf(pie_width * 0.44, size.y * 0.42)

	if radius < 8.0:
		_draw_message("Waiting for chart area")
		return

	var center := Vector2(pie_width * 0.5, size.y * 0.5)
	var start_angle := -PI / 2.0

	for i in range(graph_values.size()):
		var value := maxf(graph_values[i], 0.0)
		if value <= 0.0:
			continue

		var sweep := TAU * value / total
		var segments := maxi(3, int(ceil(sweep * 32.0)))
		var points := PackedVector2Array([center])

		for segment in range(segments + 1):
			var angle := start_angle + sweep * float(segment) / float(segments)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)

		draw_colored_polygon(points, _get_color(i))
		start_angle += sweep

	var legend_x := pie_width + 12.0
	var row_height := 64.0
	var total_legend_height := graph_values.size() * row_height
	var legend_y := maxf(28.0, (size.y - total_legend_height) * 0.5 + 20.0)

	for i in range(graph_values.size()):
		var label := graph_labels[i] if i < graph_labels.size() else "Item"
		var value := maxf(graph_values[i], 0.0)
		var percentage := value / total * 100.0

		draw_rect(
			Rect2(legend_x, legend_y - 18.0, 12.0, 12.0),
			_get_color(i)
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(legend_x + 20.0, legend_y - 2.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf(legend_width - 30.0, 20.0),
			PIE_LEGEND_FONT_SIZE,
			TEXT_COLOR
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(legend_x + 20.0, legend_y + 28.0),
			"%d (%.1f%%)" % [int(round(value)), percentage],
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf(legend_width - 30.0, 20.0),
			PIE_VALUE_FONT_SIZE,
			MUTED_COLOR
		)

		legend_y += row_height


# ------------------------------------------------------------
# LINE GRAPH
# ------------------------------------------------------------

func _draw_line_graph() -> void:
	if line_categories.is_empty() or line_series.is_empty():
		_draw_message("No quiz score data available")
		return

	var left := 65.0
	var right := 12.0
	var top := 58.0
	var bottom := 48.0
	var chart_width := size.x - left - right
	var chart_height := size.y - top - bottom

	if chart_width <= 0.0 or chart_height <= 0.0:
		return

	for step in range(5):
		var ratio := float(step) / 4.0
		var y := top + chart_height * (1.0 - ratio)
		_draw_grid_line(Vector2(left, y), Vector2(left + chart_width, y))

		draw_string(
			ThemeDB.fallback_font,
			Vector2(0.0, y + 8.0),
			"%d%%" % int(round(ratio * 100.0)),
			HORIZONTAL_ALIGNMENT_LEFT,
			left - 8.0,
			SECTION_AXIS_FONT_SIZE,
			MUTED_COLOR
		)

	var point_spacing := 0.0
	if line_categories.size() > 1:
		point_spacing = chart_width / float(line_categories.size() - 1)

	for i in range(line_categories.size()):
		var x := left + chart_width * 0.5
		if line_categories.size() > 1:
			x = left + point_spacing * float(i)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 48.0, top + chart_height + 30.0),
			line_categories[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			96.0,
			CATEGORY_FONT_SIZE,
			TEXT_COLOR
		)

	for series_index in range(line_series.size()):
		var series: Dictionary = line_series[series_index]
		var values: Array = series.get("values", [])
		var line_color := _get_color(series_index)
		var points := PackedVector2Array()
		var point_indexes: Array[int] = []

		for i in range(mini(values.size(), line_categories.size())):
			var raw_value := float(values[i])
			if raw_value < 0.0:
				continue

			var value := clampf(raw_value, 0.0, 100.0)
			var x := left + chart_width * 0.5
			if line_categories.size() > 1:
				x = left + point_spacing * float(i)

			var y := top + chart_height * (1.0 - value / 100.0)
			y = clampf(y, top + 4.0, top + chart_height - 4.0)

			points.append(Vector2(x, y))
			point_indexes.append(i)

		for i in range(points.size() - 1):
			if point_indexes[i + 1] != point_indexes[i] + 1:
				continue
			draw_line(points[i], points[i + 1], line_color, 2.5, true)

		for point in points:
			draw_circle(point, 4.0, line_color)

	_draw_line_legend()


func _draw_line_legend() -> void:
	var legend_x := 12.0
	var legend_y := 20.0
	var cursor_x := legend_x
	var row_height := 30.0
	var max_width := size.x - 12.0

	for series_index in range(line_series.size()):
		var series: Dictionary = line_series[series_index]
		var section_name := str(series.get("name", "Section"))
		var line_color := _get_color(series_index)
		var required_width := minf(190.0, section_name.length() * 14.0 + 42.0)

		if cursor_x + required_width > max_width and cursor_x > legend_x:
			cursor_x = legend_x
			legend_y += row_height

		draw_line(
			Vector2(cursor_x, legend_y),
			Vector2(cursor_x + 18.0, legend_y),
			line_color,
			3.0
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(cursor_x + 24.0, legend_y + 8.0),
			section_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf(required_width - 24.0, 20.0),
			CATEGORY_FONT_SIZE,
			TEXT_COLOR
		)

		cursor_x += required_width + 10.0


# ------------------------------------------------------------
# ATOMON COLLECTION PROGRESS
# ------------------------------------------------------------

func _draw_progress_bar() -> void:
	var count := graph_values.size()
	if count == 0:
		_draw_message("No section data available")
		return

	var margin_left := 16.0
	var margin_right := 16.0
	var margin_top := 12.0
	var content_width := size.x - margin_left - margin_right

	if content_width <= 0.0:
		return

	var row_height := ATOMON_ROW_HEIGHT
	var label_size := ATOMON_LABEL_FONT_SIZE
	var detail_size := ATOMON_VALUE_FONT_SIZE
	var bar_height := 14.0

	for i in range(count):
		var row_top := margin_top + row_height * float(i)

		var label := graph_labels[i] if i < graph_labels.size() else "Section"
		var collected := clampf(graph_values[i], 0.0, float(ELEMENTS_TOTAL))
		var percentage := collected / float(ELEMENTS_TOTAL) * 100.0

		draw_string(
			ThemeDB.fallback_font,
			Vector2(margin_left, row_top + label_size),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			content_width,
			label_size,
			TEXT_COLOR
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(margin_left, row_top + label_size + detail_size + 8.0),
			"Collected: %.1f / %d elements (%.1f%%)" % [
				collected, ELEMENTS_TOTAL, percentage
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			content_width,
			detail_size,
			MUTED_COLOR
		)

		var bar_y := row_top + 82.0
		var track := StyleBoxFlat.new()
		track.bg_color = TRACK_COLOR
		track.set_corner_radius_all(7)

		draw_style_box(
			track,
			Rect2(margin_left, bar_y, content_width, bar_height)
		)

		var fill_width := content_width * collected / float(ELEMENTS_TOTAL)
		if fill_width > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = PROGRESS_COLOR
			fill.set_corner_radius_all(7)

			draw_style_box(
				fill,
				Rect2(margin_left, bar_y, fill_width, bar_height)
			)


# ------------------------------------------------------------
# QUIZ ACTIVITY & AVERAGE SCORE BY SECTION
# ------------------------------------------------------------

func _draw_quiz_section_graph() -> void:
	var count := quiz_section_labels.size()

	if count == 0:
		_draw_message("No completed quiz results available")
		return

	var left := 205.0
	var right := 150.0
	var top := 64.0
	var bottom := 28.0

	var chart_width := size.x - left - right
	var chart_height := size.y - top - bottom

	if chart_width <= 0.0 or chart_height <= 0.0:
		return

	var row_height := chart_height / float(count)
	var bar_height := minf(20.0, row_height * 0.22)
	var gap := 6.0
	var max_results := 1

	for value in quiz_result_counts:
		max_results = maxi(max_results, value)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(left, 30.0),
		"Quiz results",
		HORIZONTAL_ALIGNMENT_LEFT,
		chart_width * 0.48,
		QUIZ_HEADER_FONT_SIZE,
		Color("#D99A36")
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x - right + 8.0, 30.0),
		"Average score",
		HORIZONTAL_ALIGNMENT_LEFT,
		right + 5.0,
		QUIZ_HEADER_FONT_SIZE,
		Color("#75A66A")
	)

	for i in range(count):
		var row_top := top + row_height * float(i)
		var center_y := row_top + row_height * 0.5

		var section_name := quiz_section_labels[i]
		var result_count := maxi(0, quiz_result_counts[i])
		var average_score := clampf(quiz_average_scores[i], 0.0, 100.0)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(8.0, center_y + 8.0),
			section_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			left - 16.0,
			QUIZ_LABEL_FONT_SIZE,
			TEXT_COLOR
		)

		var count_y := center_y - bar_height - gap * 0.5
		var count_width := chart_width * float(result_count) / float(max_results)

		draw_rect(
			Rect2(left, count_y, chart_width, bar_height),
			TRACK_COLOR
		)

		if count_width > 0.0:
			draw_rect(
				Rect2(left, count_y, count_width, bar_height),
				Color("#D99A36")
			)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(left + chart_width + 8.0, count_y + bar_height + 4.0),
			str(result_count),
			HORIZONTAL_ALIGNMENT_LEFT,
			42.0,
			QUIZ_VALUE_FONT_SIZE,
			TEXT_COLOR
		)

		var score_y := center_y + gap * 0.5
		var score_width := chart_width * average_score / 100.0

		draw_rect(
			Rect2(left, score_y, chart_width, bar_height),
			TRACK_COLOR
		)

		if score_width > 0.0:
			draw_rect(
				Rect2(left, score_y, score_width, bar_height),
				Color("#75A66A")
			)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(left + chart_width + 8.0, score_y + bar_height + 4.0),
			"%.1f%%" % average_score,
			HORIZONTAL_ALIGNMENT_LEFT,
			55.0,
			QUIZ_VALUE_FONT_SIZE,
			TEXT_COLOR
		)
