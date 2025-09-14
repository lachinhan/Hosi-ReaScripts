-- @description Language library for Reanspiration script.
-- @version 1.1 (Added JA, ZH, KO)
-- @author Hosi
-- @provides [library] Hosi/reanspiration/reanspiration_languages.lua
-- @about
--   This file contains all the text strings for the Reanspiration UI.
--   To add a new language, copy the entire 'en' table, rename the key (e.g., to 'fr' for French),
--   and translate all the string values. Then, update the 'available_languages' table in the main script.

local languages = {}

-- English Language Table
languages['en'] = {
  -- Window & Tabs
  window_title = 'Reanspiration - by Hosi (orig. phaselab)',
  tab_generation = "Generation",
  tab_performance = "Performance",
  tab_creative_tools = "Creative Tools",

  -- Generation Tab
  root_note_label = "Root Note",
  scale_type_label = "Scale Type",
  progression_label = "Progression",
  num_chords_label = "Number of Chords",
  complexity_label = "Complexity",
  tooltip_complexity = "0: Triads\n1: 7ths\n2: 9ths\n3: 11ths\n4: 13ths\n5: Altered",
  sec_dom_checkbox = "Add Secondary Dominants",
  tooltip_sec_dom = "50% chance to insert a V7 of the next chord (if it's not the tonic).",
  bass_pattern_label = "Bass Pattern",
  tooltip_bass_pattern = "Selects the pattern for the generated bassline.",
  generate_button = "Generate Chords & Bass",
  add_note_button = "Add Note",
  delete_chords_button = "Delete Chords (Keep Bass/Melody)",
  tooltip_delete_chords = "Deletes chord notes, keeping the generated bassline and melody.",
  
  -- Performance Tab
  transpose_label = "Transpose",
  spread_label = "Spread",
  tooltip_spread = "Controls spacing between chord notes (0=Tight, 2=Open).",
  voicing_label = "Voicing",
  tooltip_voicing = "Applies advanced voicing techniques (requires 4+ notes).",
  humanize_section_title = "Humanize",
  humanize_timing_label = "Timing +/- (PPQ)",
  humanize_velocity_label = "Velocity +/-",
  humanize_button = "Humanize Notes",
  tooltip_humanize = "Slightly randomizes the timing and velocity of all notes in the item.",
  undo_humanize_button = "Undo Humanize",

  -- Creative Tools Tab
  melody_section_title = "Melody Generation",
  melody_contour_label = "Contour",
  tooltip_melody_contour = "Sets the overall melodic shape.",
  melody_target_checkbox = "Target Chord Tones on Beats",
  tooltip_melody_target = "Prioritizes notes from the underlying chord on strong beats.",
  melody_density_label = "Density",
  melody_min_oct_label = "Min Octave",
  melody_max_oct_label = "Max Octave",
  melody_generate_button = "Generate Melody",
  tooltip_melody_generate = "Generates a new melody over existing chords.\nDeletes any previous melody.",
  undo_melody_button = "Undo Melody",
  
  arp_strum_section_title = "Arpeggiator / Strummer",
  arp_strum_pattern_label = "Pattern##Arp",
  arp_strum_delay_label = "Strum Delay (PPQ)",
  arp_strum_velocity_label = "Up-strum Velocity (%)",
  tooltip_arp_strum_velocity = "Sets the velocity of up-strums as a percentage of the original note's velocity.",
  arp_rate_label = "Arp Rate",
  arp_apply_button = "Apply Arp/Strum",
  tooltip_arp_apply = "Applies pattern to selected notes (or all if none selected).",
  undo_arp_button = "Undo Arp/Strum",
  
  rhythm_section_title = "Rhythm Applicator",
  rhythm_pattern_label = "Rhythm Pattern",
  rhythm_apply_button = "Apply Rhythm",
  tooltip_rhythm_apply = "Applies the selected rhythmic pattern to the chords.",

  -- Other UI
  donate_button = "Donate",
  feedback_generated = "Generated: %s %s",
  melody_error_no_chords = "Could not find enough chords in the item to generate a melody.",
  rhythm_error_no_state = "Error: No initial state found. Generate chords first.\n",
  add_note_error_no_notes = "Error: No notes found. Cannot add a new note.\n",
  add_note_error_no_scale = "Error: Could not detect a suitable scale. Cannot add a new note.\n",
  add_note_error_no_chords = "Error: No chords found. Cannot add a new note.\n",
}

-- Vietnamese Language Table
languages['vi'] = {
  -- Window & Tabs
  window_title = 'Reanspiration - bởi Hosi (gốc. phaselab)',
  tab_generation = "Hòa Âm",
  tab_performance = "Diễn Tấu",
  tab_creative_tools = "Sáng Tạo",

  -- Generation Tab
  root_note_label = "Chủ Âm",
  scale_type_label = "Loại Âm Giai",
  progression_label = "Vòng Hòa Âm",
  num_chords_label = "Số Hợp Âm",
  complexity_label = "Độ Phức Tạp",
  tooltip_complexity = "0: Hợp âm ba\n1: Hợp âm 7\n2: Hợp âm 9\n3: Hợp âm 11\n4: Hợp âm 13\n5: Hợp âm biến đổi",
  sec_dom_checkbox = "Thêm Hợp Âm Át Thứ Cấp",
  tooltip_sec_dom = "50% cơ hội chèn một hợp âm V7 của hợp âm kế tiếp (nếu đó không phải chủ âm).",
  bass_pattern_label = "Mẫu Bè Trầm (Bass)",
  tooltip_bass_pattern = "Chọn một mẫu cho bè trầm được tạo ra.",
  generate_button = "Tạo Hợp Âm & Bass",
  add_note_button = "Thêm Nốt",
  delete_chords_button = "Xóa Hợp Âm (Giữ Bass/Giai điệu)",
  tooltip_delete_chords = "Chỉ xóa các nốt hợp âm, giữ lại bè trầm và giai điệu đã tạo.",
  
  -- Performance Tab
  transpose_label = "Dịch Giọng",
  spread_label = "Độ Rộng",
  tooltip_spread = "Điều chỉnh khoảng cách giữa các nốt trong hợp âm (0=Hẹp, 2=Rộng).",
  voicing_label = "Thế Đảo",
  tooltip_voicing = "Áp dụng các kỹ thuật thế đảo nâng cao (cần 4+ nốt).",
  humanize_section_title = "Tạo Cảm Giác Tự Nhiên (Humanize)",
  humanize_timing_label = "Thời Gian +/- (PPQ)",
  humanize_velocity_label = "Cường Độ +/-",
  humanize_button = "Áp Dụng Humanize",
  tooltip_humanize = "Ngẫu nhiên hóa một chút về thời gian và cường độ của tất cả nốt trong item.",
  undo_humanize_button = "Hoàn Tác Humanize",

  -- Creative Tools Tab
  melody_section_title = "Tạo Giai Điệu",
  melody_contour_label = "Đường Nét",
  tooltip_melody_contour = "Thiết lập hình dạng tổng thể của giai điệu.",
  melody_target_checkbox = "Ưu Tiên Nốt Hợp Âm",
  tooltip_melody_target = "Ưu tiên các nốt trong hợp âm nền tại các phách mạnh.",
  melody_density_label = "Mật Độ Nốt",
  melody_min_oct_label = "Quãng 8 Thấp Nhất",
  melody_max_oct_label = "Quãng 8 Cao Nhất",
  melody_generate_button = "Tạo Giai Điệu",
  tooltip_melody_generate = "Tạo một giai điệu mới dựa trên các hợp âm có sẵn.\nXóa giai điệu đã tạo trước đó.",
  undo_melody_button = "Hoàn Tác Giai Điệu",
  
  arp_strum_section_title = "Rải Hợp Âm / Quạt Chả (Arp/Strum)",
  arp_strum_pattern_label = "Mẫu##Arp",
  arp_strum_delay_label = "Độ Trễ (PPQ)",
  arp_strum_velocity_label = "Cường Độ Đánh Lên (%)",
  tooltip_arp_strum_velocity = "Thiết lập cường độ của các lần đánh lên (up-strum) theo phần trăm của cường độ gốc.",
  arp_rate_label = "Tốc Độ Rải",
  arp_apply_button = "Áp Dụng Arp/Strum",
  tooltip_arp_apply = "Áp dụng mẫu cho các nốt được chọn (hoặc tất cả nếu không có nốt nào được chọn).",
  undo_arp_button = "Hoàn Tác Arp/Strum",
  
  rhythm_section_title = "Áp Dụng Tiết Tấu",
  rhythm_pattern_label = "Mẫu Tiết Tấu",
  rhythm_apply_button = "Áp Dụng Tiết Tấu",
  tooltip_rhythm_apply = "Áp dụng mẫu tiết tấu đã chọn cho các hợp âm.",

  -- Other UI
  donate_button = "Ủng Hộ",
  feedback_generated = "Đã tạo: %s %s",
  melody_error_no_chords = "Không tìm thấy đủ hợp âm trong item để tạo giai điệu.",
  rhythm_error_no_state = "Lỗi: Không tìm thấy trạng thái ban đầu. Hãy tạo hợp âm trước.\n",
  add_note_error_no_notes = "Lỗi: Không tìm thấy nốt nhạc. Không thể thêm nốt mới.\n",
  add_note_error_no_scale = "Lỗi: Không thể nhận diện âm giai phù hợp. Không thể thêm nốt mới.\n",
  add_note_error_no_chords = "Lỗi: Không tìm thấy hợp âm. Không thể thêm nốt mới.\n",
}

-- Japanese Language Table
languages['ja'] = {
  -- Window & Tabs
  window_title = 'Reanspiration - 作 Hosi (原案 phaselab)',
  tab_generation = "生成",
  tab_performance = "演奏",
  tab_creative_tools = "創作ツール",

  -- Generation Tab
  root_note_label = "ルート音",
  scale_type_label = "スケールタイプ",
  progression_label = "コード進行",
  num_chords_label = "コード数",
  complexity_label = "複雑さ",
  tooltip_complexity = "0: 三和音\n1: 7thコード\n2: 9thコード\n3: 11thコード\n4: 13thコード\n5: オルタード",
  sec_dom_checkbox = "セカンダリードミナントを追加",
  tooltip_sec_dom = "次のコード（トニックでない場合）のV7を50%の確率で挿入します。",
  bass_pattern_label = "ベースパターン",
  tooltip_bass_pattern = "生成されるベースラインのパターンを選択します。",
  generate_button = "コードとベースを生成",
  add_note_button = "ノートを追加",
  delete_chords_button = "コードを削除 (ベース/メロディは維持)",
  tooltip_delete_chords = "生成されたベースラインとメロディを維持したまま、コードノートを削除します。",
  
  -- Performance Tab
  transpose_label = "移調",
  spread_label = "スプレッド",
  tooltip_spread = "コードノート間の間隔を制御します (0=狭い, 2=広い)。",
  voicing_label = "ボイシング",
  tooltip_voicing = "高度なボイシング技術を適用します（4つ以上のノートが必要）。",
  humanize_section_title = "ヒューマナイズ",
  humanize_timing_label = "タイミング +/- (PPQ)",
  humanize_velocity_label = "ベロシティ +/-",
  humanize_button = "ノートをヒューマナイズ",
  tooltip_humanize = "アイテム内のすべてのノートのタイミングとベロシティをわずかにランダム化します。",
  undo_humanize_button = "ヒューマナイズを元に戻す",

  -- Creative Tools Tab
  melody_section_title = "メロディ生成",
  melody_contour_label = "輪郭",
  tooltip_melody_contour = "メロディ全体の形状を設定します。",
  melody_target_checkbox = "拍点でコードトーンを狙う",
  tooltip_melody_target = "強い拍で基になるコードのノートを優先します。",
  melody_density_label = "密度",
  melody_min_oct_label = "最低オクターブ",
  melody_max_oct_label = "最高オクターブ",
  melody_generate_button = "メロディを生成",
  tooltip_melody_generate = "既存のコードの上に新しいメロディを生成します。\n以前のメロディは削除されます。",
  undo_melody_button = "メロディを元に戻す",
  
  arp_strum_section_title = "アルペジエーター / ストラマー",
  arp_strum_pattern_label = "パターン##Arp",
  arp_strum_delay_label = "ストラム遅延 (PPQ)",
  arp_strum_velocity_label = "アップストラムのベロシティ (%)",
  tooltip_arp_strum_velocity = "アップストラムのベロシティを元のノートのベロシティに対するパーセンテージで設定します。",
  arp_rate_label = "アルペジオレート",
  arp_apply_button = "アルペジオ/ストラムを適用",
  tooltip_arp_apply = "選択したノート（選択がない場合はすべて）にパターンを適用します。",
  undo_arp_button = "アルペジオ/ストラムを元に戻す",
  
  rhythm_section_title = "リズムアプリケーター",
  rhythm_pattern_label = "リズムパターン",
  rhythm_apply_button = "リズムを適用",
  tooltip_rhythm_apply = "選択したリズムパターンをコードに適用します。",

  -- Other UI
  donate_button = "寄付",
  feedback_generated = "生成: %s %s",
  melody_error_no_chords = "アイテム内にメロディを生成するのに十分なコードが見つかりませんでした。",
  rhythm_error_no_state = "エラー: 初期状態が見つかりません。最初にコードを生成してください。\n",
  add_note_error_no_notes = "エラー: ノートが見つかりません。新しいノートを追加できません。\n",
  add_note_error_no_scale = "エラー: 適切なスケールを検出できませんでした。新しいノートを追加できません。\n",
  add_note_error_no_chords = "エラー: コードが見つかりません。新しいノートを追加できません。\n",
}

-- Chinese (Simplified) Language Table
languages['zh'] = {
  -- Window & Tabs
  window_title = 'Reanspiration - 作者 Hosi (原创 phaselab)',
  tab_generation = "生成",
  tab_performance = "演奏",
  tab_creative_tools = "创意工具",

  -- Generation Tab
  root_note_label = "根音",
  scale_type_label = "音阶类型",
  progression_label = "和弦进行",
  num_chords_label = "和弦数量",
  complexity_label = "复杂度",
  tooltip_complexity = "0: 三和弦\n1: 七和弦\n2: 九和弦\n3: 十一和弦\n4: 十三和弦\n5: 变化和弦",
  sec_dom_checkbox = "添加次属和弦",
  tooltip_sec_dom = "有50%的几率在下一个和弦（如果不是主和弦）前插入其V7和弦。",
  bass_pattern_label = "贝斯模式",
  tooltip_bass_pattern = "为生成的贝斯声部选择模式。",
  generate_button = "生成和弦与贝斯",
  add_note_button = "添加音符",
  delete_chords_button = "删除和弦 (保留贝斯/旋律)",
  tooltip_delete_chords = "删除和弦音符，同时保留已生成的贝斯和旋律。",
  
  -- Performance Tab
  transpose_label = "移调",
  spread_label = "分布",
  tooltip_spread = "控制和弦音符之间的间距 (0=紧凑, 2=开放)。",
  voicing_label = "声部配置",
  tooltip_voicing = "应用高级声部配置技巧（需要4个以上音符）。",
  humanize_section_title = "人性化",
  humanize_timing_label = "时间 +/- (PPQ)",
  humanize_velocity_label = "力度 +/-",
  humanize_button = "人性化音符",
  tooltip_humanize = "对项目中的所有音符的时间和力度进行轻微的随机化处理。",
  undo_humanize_button = "撤销人性化",

  -- Creative Tools Tab
  melody_section_title = "旋律生成",
  melody_contour_label = "轮廓",
  tooltip_melody_contour = "设置旋律的整体形状。",
  melody_target_checkbox = "在节拍上对准和弦音",
  tooltip_melody_target = "在强拍上优先使用背景和弦的音符。",
  melody_density_label = "密度",
  melody_min_oct_label = "最低八度",
  melody_max_oct_label = "最高八度",
  melody_generate_button = "生成旋律",
  tooltip_melody_generate = "在现有和弦上生成新的旋律。\n将删除之前生成的任何旋律。",
  undo_melody_button = "撤销旋律",
  
  arp_strum_section_title = "琶音/扫弦",
  arp_strum_pattern_label = "模式##Arp",
  arp_strum_delay_label = "扫弦延迟 (PPQ)",
  arp_strum_velocity_label = "上扫力度 (%)",
  tooltip_arp_strum_velocity = "将上扫的力度设置为原始音符力度的百分比。",
  arp_rate_label = "琶音速率",
  arp_apply_button = "应用琶音/扫弦",
  tooltip_arp_apply = "将模式应用于选定的音符（如果未选择，则应用于所有音符）。",
  undo_arp_button = "撤销琶音/扫弦",
  
  rhythm_section_title = "节奏应用器",
  rhythm_pattern_label = "节奏模式",
  rhythm_apply_button = "应用节奏",
  tooltip_rhythm_apply = "将选定的节奏模式应用于和弦。",

  -- Other UI
  donate_button = "捐赠",
  feedback_generated = "已生成: %s %s",
  melody_error_no_chords = "在项目中找不到足够的和弦来生成旋律。",
  rhythm_error_no_state = "错误：找不到初始状态。请先生成和弦。\n",
  add_note_error_no_notes = "错误：找不到音符。无法添加新音符。\n",
  add_note_error_no_scale = "错误：无法检测到合适的音阶。无法添加新音符。\n",
  add_note_error_no_chords = "错误：找不到和弦。无法添加新音符。\n",
}

-- Korean Language Table
languages['ko'] = {
  -- Window & Tabs
  window_title = 'Reanspiration - 제작 Hosi (원안 phaselab)',
  tab_generation = "생성",
  tab_performance = "연주",
  tab_creative_tools = "창작 도구",

  -- Generation Tab
  root_note_label = "루트 음",
  scale_type_label = "스케일 종류",
  progression_label = "코드 진행",
  num_chords_label = "코드 수",
  complexity_label = "복잡도",
  tooltip_complexity = "0: 3화음\n1: 7화음\n2: 9화음\n3: 11화음\n4: 13화음\n5: 얼터드",
  sec_dom_checkbox = "세컨더리 도미넌트 추가",
  tooltip_sec_dom = "다음 코드(토닉이 아닌 경우)의 V7을 50% 확률로 삽입합니다.",
  bass_pattern_label = "베이스 패턴",
  tooltip_bass_pattern = "생성된 베이스 라인의 패턴을 선택합니다.",
  generate_button = "코드 및 베이스 생성",
  add_note_button = "음표 추가",
  delete_chords_button = "코드 삭제 (베이스/멜로디 유지)",
  tooltip_delete_chords = "생성된 베이스 라인과 멜로디는 유지하고 코드 음표만 삭제합니다.",
  
  -- Performance Tab
  transpose_label = "조옮김",
  spread_label = "펼침",
  tooltip_spread = "코드 음표 간의 간격을 조절합니다 (0=좁게, 2=넓게).",
  voicing_label = "보이싱",
  tooltip_voicing = "고급 보이싱 기법을 적용합니다 (4개 이상의 음표 필요).",
  humanize_section_title = "인간화",
  humanize_timing_label = "타이밍 +/- (PPQ)",
  humanize_velocity_label = "벨로시티 +/-",
  humanize_button = "음표 인간화",
  tooltip_humanize = "항목의 모든 음표의 타이밍과 벨로시티를 약간 무작위화합니다.",
  undo_humanize_button = "인간화 취소",

  -- Creative Tools Tab
  melody_section_title = "멜로디 생성",
  melody_contour_label = "윤곽",
  tooltip_melody_contour = "멜로디의 전체적인 모양을 설정합니다.",
  melody_target_checkbox = "박자에 코드 톤 타겟팅",
  tooltip_melody_target = "강박에서 기본 코드의 음을 우선적으로 사용합니다.",
  melody_density_label = "밀도",
  melody_min_oct_label = "최저 옥타브",
  melody_max_oct_label = "최고 옥타브",
  melody_generate_button = "멜로디 생성",
  tooltip_melody_generate = "기존 코드 위에 새로운 멜로디를 생성합니다.\n이전 멜로디는 삭제됩니다.",
  undo_melody_button = "멜로디 취소",
  
  arp_strum_section_title = "아르페지에이터 / 스트러머",
  arp_strum_pattern_label = "패턴##Arp",
  arp_strum_delay_label = "스트럼 딜레이 (PPQ)",
  arp_strum_velocity_label = "업 스트럼 벨로시티 (%)",
  tooltip_arp_strum_velocity = "업 스트럼의 벨로시티를 원래 음표 벨로시티의 백분율로 설정합니다.",
  arp_rate_label = "아르페지오 속도",
  arp_apply_button = "아르페지오/스트럼 적용",
  tooltip_arp_apply = "선택한 음표(선택이 없으면 전체)에 패턴을 적용합니다.",
  undo_arp_button = "아르페지오/스트럼 취소",
  
  rhythm_section_title = "리듬 적용기",
  rhythm_pattern_label = "리듬 패턴",
  rhythm_apply_button = "리듬 적용",
  tooltip_rhythm_apply = "선택한 리듬 패턴을 코드에 적용합니다.",

  -- Other UI
  donate_button = "후원하기",
  feedback_generated = "생성됨: %s %s",
  melody_error_no_chords = "항목에서 멜로디를 생성하기에 충분한 코드를 찾을 수 없습니다.",
  rhythm_error_no_state = "오류: 초기 상태를 찾을 수 없습니다. 먼저 코드를 생성하십시오.\n",
  add_note_error_no_notes = "오류: 음표를 찾을 수 없습니다. 새 음표를 추가할 수 없습니다.\n",
  add_note_error_no_scale = "오류: 적절한 스케일을 감지할 수 없습니다. 새 음표를 추가할 수 없습니다.\n",
  add_note_error_no_chords = "오류: 코드를 찾을 수 없습니다. 새 음표를 추가할 수 없습니다.\n",
}

return languages

