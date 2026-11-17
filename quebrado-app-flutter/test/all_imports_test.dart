// GENERADO por tool/generate_all_imports_test.sh — no editar a mano.
// Importa todo lib/ (excepto archivos solo-web) para que la cobertura sea real.
// ignore_for_file: unused_import, directives_ordering

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:quebrado_app_flutter/agente/agente.dart' as i0;
import 'package:quebrado_app_flutter/agente/dialogs/agente_settings_dialog.dart' as i1;
import 'package:quebrado_app_flutter/agente/dialogs/prompt_editor_dialog.dart' as i2;
import 'package:quebrado_app_flutter/agente/models/agente_prompt_model.dart' as i3;
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart' as i4;
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart' as i5;
import 'package:quebrado_app_flutter/agente/models/chat_session_model.dart' as i6;
import 'package:quebrado_app_flutter/agente/screens/agente_home_screen.dart' as i7;
import 'package:quebrado_app_flutter/agente/screens/chat_conversation_screen.dart' as i8;
import 'package:quebrado_app_flutter/agente/services/agente_supabase_service.dart' as i9;
import 'package:quebrado_app_flutter/agente/services/gemini_config.dart' as i10;
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart' as i11;
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart' as i12;
import 'package:quebrado_app_flutter/agente/theme/agente_colors.dart' as i13;
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart' as i14;
import 'package:quebrado_app_flutter/agente/widgets/action_proposal_card_view.dart' as i15;
import 'package:quebrado_app_flutter/agente/widgets/agente_chat_bottom_sheet.dart' as i16;
import 'package:quebrado_app_flutter/agente/widgets/artifact_card_view.dart' as i17;
import 'package:quebrado_app_flutter/agente/widgets/chat_message_bubble.dart' as i18;
import 'package:quebrado_app_flutter/agente/widgets/docked_launcher_chat.dart' as i19;
import 'package:quebrado_app_flutter/diario/dialogs/category_editor_dialog.dart' as i20;
import 'package:quebrado_app_flutter/diario/dialogs/contact_editor_dialog.dart' as i21;
import 'package:quebrado_app_flutter/diario/dialogs/entry_reader_dialog.dart' as i22;
import 'package:quebrado_app_flutter/diario/dialogs/quick_note_dialog.dart' as i23;
import 'package:quebrado_app_flutter/diario/diario.dart' as i24;
import 'package:quebrado_app_flutter/diario/models/diario_category.dart' as i25;
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart' as i26;
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart' as i27;
import 'package:quebrado_app_flutter/diario/models/diario_template.dart' as i28;
import 'package:quebrado_app_flutter/diario/models/mood_catalog.dart' as i29;
import 'package:quebrado_app_flutter/diario/models/mood_log.dart' as i30;
import 'package:quebrado_app_flutter/diario/models/mood_tag.dart' as i31;
import 'package:quebrado_app_flutter/diario/screens/animo_dashboard_screen.dart' as i32;
import 'package:quebrado_app_flutter/diario/screens/contact_detail_screen.dart' as i33;
import 'package:quebrado_app_flutter/diario/screens/diario_home_screen.dart' as i34;
import 'package:quebrado_app_flutter/diario/screens/diario_search_screen.dart' as i35;
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart' as i36;
import 'package:quebrado_app_flutter/diario/screens/template_manager_screen.dart' as i37;
import 'package:quebrado_app_flutter/diario/services/animo_supabase_service.dart' as i38;
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart' as i39;
import 'package:quebrado_app_flutter/diario/services/speech_recognition_service.dart' as i40;
import 'package:quebrado_app_flutter/diario/theme/diario_colors.dart' as i41;
import 'package:quebrado_app_flutter/diario/viewmodels/animo_state.dart' as i42;
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart' as i43;
import 'package:quebrado_app_flutter/diario/widgets/clipboard_image_helper.dart' as i44;
import 'package:quebrado_app_flutter/diario/widgets/clipboard_image_io.dart' as i45;
import 'package:quebrado_app_flutter/diario/widgets/contact_mood_section.dart' as i46;
import 'package:quebrado_app_flutter/diario/widgets/diario_image_helper.dart' as i47;
import 'package:quebrado_app_flutter/diario/widgets/diario_rich_editing.dart' as i48;
import 'package:quebrado_app_flutter/diario/widgets/mention_text_field.dart' as i49;
import 'package:quebrado_app_flutter/diario/widgets/mood_checkin_sheet.dart' as i50;
import 'package:quebrado_app_flutter/diario/widgets/mood_emotion_picker.dart' as i51;
import 'package:quebrado_app_flutter/diario/widgets/mood_log_tile.dart' as i52;
import 'package:quebrado_app_flutter/diario/widgets/mood_month_calendar.dart' as i53;
import 'package:quebrado_app_flutter/diario/widgets/mood_quick_bar.dart' as i54;
import 'package:quebrado_app_flutter/diario/widgets/mood_trend_chart.dart' as i55;
import 'package:quebrado_app_flutter/diario/widgets/personal_notes_view.dart' as i56;
import 'package:quebrado_app_flutter/habitos/dialogs/habit_detail_cli_dialog.dart' as i57;
import 'package:quebrado_app_flutter/habitos/dialogs/habit_terminal_editor_dialog.dart' as i58;
import 'package:quebrado_app_flutter/habitos/habitos.dart' as i59;
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart' as i60;
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart' as i61;
import 'package:quebrado_app_flutter/habitos/models/habit_stack_model.dart' as i62;
import 'package:quebrado_app_flutter/habitos/screens/habitos_home_screen.dart' as i63;
import 'package:quebrado_app_flutter/habitos/screens/habitos_metrics_screen.dart' as i64;
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart' as i65;
import 'package:quebrado_app_flutter/habitos/theme/habitos_terminal_theme.dart' as i66;
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart' as i67;
import 'package:quebrado_app_flutter/main.dart' as i68;
import 'package:quebrado_app_flutter/notas/dialogs/category_manager_dialog.dart' as i69;
import 'package:quebrado_app_flutter/notas/dialogs/note_reader_dialog.dart' as i70;
import 'package:quebrado_app_flutter/notas/models/note_block.dart' as i71;
import 'package:quebrado_app_flutter/notas/models/note_category.dart' as i72;
import 'package:quebrado_app_flutter/notas/models/note_item.dart' as i73;
import 'package:quebrado_app_flutter/notas/notas.dart' as i74;
import 'package:quebrado_app_flutter/notas/screens/notas_home_screen.dart' as i75;
import 'package:quebrado_app_flutter/notas/screens/note_editor_screen.dart' as i76;
import 'package:quebrado_app_flutter/notas/services/notas_supabase_service.dart' as i77;
import 'package:quebrado_app_flutter/notas/services/note_document_converter.dart' as i78;
import 'package:quebrado_app_flutter/notas/services/note_pdf_service.dart' as i79;
import 'package:quebrado_app_flutter/notas/theme/notas_colors.dart' as i80;
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart' as i81;
import 'package:quebrado_app_flutter/notas/widgets/note_block_widget.dart' as i82;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_account_dialog.dart' as i83;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_action_selection_sheet.dart' as i84;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_category_dialog.dart' as i85;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_exchange_dialog.dart' as i86;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_recurring_payment_dialog.dart' as i87;
import 'package:quebrado_app_flutter/quebrado/dialogs/add_transaction_dialog.dart' as i88;
import 'package:quebrado_app_flutter/quebrado/dialogs/book_selector_dialog.dart' as i89;
import 'package:quebrado_app_flutter/quebrado/dialogs/calculator_dialog.dart' as i90;
import 'package:quebrado_app_flutter/quebrado/dialogs/cross_profile_transfer_dialog.dart' as i91;
import 'package:quebrado_app_flutter/quebrado/dialogs/day_actions_dialog.dart' as i92;
import 'package:quebrado_app_flutter/quebrado/dialogs/partial_payment_dialog.dart' as i93;
import 'package:quebrado_app_flutter/quebrado/dialogs/pending_confirmations_dialog.dart' as i94;
import 'package:quebrado_app_flutter/quebrado/dialogs/pin_setup_bottom_sheet.dart' as i95;
import 'package:quebrado_app_flutter/quebrado/dialogs/pin_verification_dialog.dart' as i96;
import 'package:quebrado_app_flutter/quebrado/dialogs/pocket_details_bottom_sheet.dart' as i97;
import 'package:quebrado_app_flutter/quebrado/dialogs/purchase_simulation_bottom_sheet.dart' as i98;
import 'package:quebrado_app_flutter/quebrado/dialogs/super_app_hub_sheet.dart' as i99;
import 'package:quebrado_app_flutter/quebrado/dialogs/transaction_detail_dialog.dart' as i100;
import 'package:quebrado_app_flutter/quebrado/dialogs/transfer_bank_dialog.dart' as i101;
import 'package:quebrado_app_flutter/quebrado/models/account.dart' as i102;
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart' as i103;
import 'package:quebrado_app_flutter/quebrado/models/exchange_rate_record.dart' as i104;
import 'package:quebrado_app_flutter/quebrado/models/market_item.dart' as i105;
import 'package:quebrado_app_flutter/quebrado/models/market_product.dart' as i106;
import 'package:quebrado_app_flutter/quebrado/models/market_shopping_list.dart' as i107;
import 'package:quebrado_app_flutter/quebrado/models/market_shopping_list_item.dart' as i108;
import 'package:quebrado_app_flutter/quebrado/models/market_store.dart' as i109;
import 'package:quebrado_app_flutter/quebrado/models/market_trip.dart' as i110;
import 'package:quebrado_app_flutter/quebrado/models/mobile_payment_recipient.dart' as i111;
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart' as i112;
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment_partial.dart' as i113;
import 'package:quebrado_app_flutter/quebrado/models/saving_pocket.dart' as i114;
import 'package:quebrado_app_flutter/quebrado/models/timeline_day_summary.dart' as i115;
import 'package:quebrado_app_flutter/quebrado/models/timeline_event.dart' as i116;
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart' as i117;
import 'package:quebrado_app_flutter/quebrado/models/transaction_category.dart' as i118;
import 'package:quebrado_app_flutter/quebrado/quebrado.dart' as i119;
import 'package:quebrado_app_flutter/quebrado/screens/account_management_screen.dart' as i120;
import 'package:quebrado_app_flutter/quebrado/screens/backup_management_screen.dart' as i121;
import 'package:quebrado_app_flutter/quebrado/screens/category_management_screen.dart' as i122;
import 'package:quebrado_app_flutter/quebrado/screens/dashboard_screen.dart' as i123;
import 'package:quebrado_app_flutter/quebrado/screens/main_screen.dart' as i124;
import 'package:quebrado_app_flutter/quebrado/screens/market_screen.dart' as i125;
import 'package:quebrado_app_flutter/quebrado/screens/market_shopping_list_screen.dart' as i126;
import 'package:quebrado_app_flutter/quebrado/screens/market_trip_screen.dart' as i127;
import 'package:quebrado_app_flutter/quebrado/screens/market_trip_store_screen.dart' as i128;
import 'package:quebrado_app_flutter/quebrado/screens/mobile_payment_recipient_screen.dart' as i129;
import 'package:quebrado_app_flutter/quebrado/screens/pockets_screen.dart' as i130;
import 'package:quebrado_app_flutter/quebrado/screens/rates_history_screen.dart' as i131;
import 'package:quebrado_app_flutter/quebrado/screens/settings_screen.dart' as i132;
import 'package:quebrado_app_flutter/quebrado/screens/timeline_screen.dart' as i133;
import 'package:quebrado_app_flutter/quebrado/screens/transactions_history_screen.dart' as i134;
import 'package:quebrado_app_flutter/quebrado/services/backup_service.dart' as i135;
import 'package:quebrado_app_flutter/quebrado/services/bcv_predictor.dart' as i136;
import 'package:quebrado_app_flutter/quebrado/services/biometric_service.dart' as i137;
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart' as i138;
import 'package:quebrado_app_flutter/quebrado/services/notification_manager.dart' as i139;
import 'package:quebrado_app_flutter/quebrado/services/rate_service.dart' as i140;
import 'package:quebrado_app_flutter/quebrado/services/supabase_config.dart' as i141;
import 'package:quebrado_app_flutter/quebrado/services/supabase_service.dart' as i142;
import 'package:quebrado_app_flutter/quebrado/theme/colors.dart' as i143;
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart' as i144;
import 'package:quebrado_app_flutter/quebrado/widgets/add_market_item_bottom_sheet.dart' as i145;
import 'package:quebrado_app_flutter/quebrado/widgets/add_market_product_bottom_sheet.dart' as i146;
import 'package:quebrado_app_flutter/quebrado/widgets/add_market_store_bottom_sheet.dart' as i147;
import 'package:quebrado_app_flutter/quebrado/widgets/add_shopping_list_item_bottom_sheet.dart' as i148;
import 'package:quebrado_app_flutter/quebrado/widgets/animated_progress_bar.dart' as i149;
import 'package:quebrado_app_flutter/quebrado/widgets/claymorphic_background.dart' as i150;
import 'package:quebrado_app_flutter/quebrado/widgets/claymorphic_card.dart' as i151;
import 'package:quebrado_app_flutter/quebrado/widgets/currency_pill.dart' as i152;
import 'package:quebrado_app_flutter/quebrado/widgets/dashboard_charts_card.dart' as i153;
import 'package:quebrado_app_flutter/quebrado/widgets/exchange_suggestion_row.dart' as i154;
import 'package:quebrado_app_flutter/quebrado/widgets/helpers.dart' as i155;
import 'package:quebrado_app_flutter/quebrado/widgets/pocket_card.dart' as i156;
import 'package:quebrado_app_flutter/quebrado/widgets/product_details_bottom_sheet.dart' as i157;
import 'package:quebrado_app_flutter/quebrado/widgets/slide_to_confirm_button.dart' as i158;
import 'package:quebrado_app_flutter/quebrado/widgets/timeline_event_row.dart' as i159;
import 'package:quebrado_app_flutter/recordatorios/dialogs/command_palette_dialog.dart' as i160;
import 'package:quebrado_app_flutter/recordatorios/dialogs/covey_guide_dialog.dart' as i161;
import 'package:quebrado_app_flutter/recordatorios/dialogs/reminder_editor_dialog.dart' as i162;
import 'package:quebrado_app_flutter/recordatorios/dialogs/role_manager_dialog.dart' as i163;
import 'package:quebrado_app_flutter/recordatorios/dialogs/sunday_planning_wizard_dialog.dart' as i164;
import 'package:quebrado_app_flutter/recordatorios/models/covey_quadrant.dart' as i165;
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart' as i166;
import 'package:quebrado_app_flutter/recordatorios/models/role_model.dart' as i167;
import 'package:quebrado_app_flutter/recordatorios/models/weekly_plan_model.dart' as i168;
import 'package:quebrado_app_flutter/recordatorios/recordatorios.dart' as i169;
import 'package:quebrado_app_flutter/recordatorios/screens/reminders_home_screen.dart' as i170;
import 'package:quebrado_app_flutter/recordatorios/services/nlp_parser.dart' as i171;
import 'package:quebrado_app_flutter/recordatorios/services/reminders_supabase_service.dart' as i172;
import 'package:quebrado_app_flutter/recordatorios/theme/reminders_colors.dart' as i173;
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart' as i174;
import 'package:quebrado_app_flutter/recordatorios/widgets/covey_matrix_view.dart' as i175;
import 'package:quebrado_app_flutter/recordatorios/widgets/weekly_schedule_view.dart' as i176;
import 'package:quebrado_app_flutter/rich_editor/block_menu.dart' as i177;
import 'package:quebrado_app_flutter/rich_editor/custom_blocks.dart' as i178;
import 'package:quebrado_app_flutter/rich_editor/dictation.dart' as i179;
import 'package:quebrado_app_flutter/rich_editor/draft_banner.dart' as i180;
import 'package:quebrado_app_flutter/rich_editor/draft_store.dart' as i181;
import 'package:quebrado_app_flutter/rich_editor/escape_to_close.dart' as i182;
import 'package:quebrado_app_flutter/rich_editor/format_toolbar.dart' as i183;
import 'package:quebrado_app_flutter/rich_editor/mentions.dart' as i184;
import 'package:quebrado_app_flutter/rich_editor/plain_text.dart' as i185;
import 'package:quebrado_app_flutter/rich_editor/rich_document_editor.dart' as i186;
import 'package:quebrado_app_flutter/rich_editor/rich_document_viewer.dart' as i187;
import 'package:quebrado_app_flutter/rich_editor/rich_editor_colors.dart' as i188;
import 'package:quebrado_app_flutter/screens/app_launcher_screen.dart' as i189;
import 'package:quebrado_app_flutter/screens/launcher_action_hub_view.dart' as i190;
import 'package:quebrado_app_flutter/services/media_storage_service.dart' as i191;
import 'package:quebrado_app_flutter/services/notification_manager.dart' as i192;
import 'package:quebrado_app_flutter/services/supabase_config.dart' as i193;
import 'package:quebrado_app_flutter/services/supabase_service.dart' as i194;
import 'package:quebrado_app_flutter/services/web_splash.dart' as i195;
import 'package:quebrado_app_flutter/services/web_splash_stub.dart' as i196;
import 'package:quebrado_app_flutter/theme/colors.dart' as i197;
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart' as i198;
import 'package:quebrado_app_flutter/theme/ortiz_space.dart' as i199;
import 'package:quebrado_app_flutter/theme/ortiz_theme.dart' as i200;
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart' as i201;
import 'package:quebrado_app_flutter/theme/ortiz_type.dart' as i202;
import 'package:quebrado_app_flutter/theme/suite_apps.dart' as i203;
import 'package:quebrado_app_flutter/viewmodels/app_state.dart' as i204;
import 'package:quebrado_app_flutter/widgets/desktop_command_center_view.dart' as i205;
import 'package:quebrado_app_flutter/widgets/responsive_breakpoints.dart' as i206;
import 'package:quebrado_app_flutter/widgets/responsive_sheet_helper.dart' as i207;
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart' as i208;

const _importados = <String>[
  'agente/agente.dart',
  'agente/dialogs/agente_settings_dialog.dart',
  'agente/dialogs/prompt_editor_dialog.dart',
  'agente/models/agente_prompt_model.dart',
  'agente/models/chat_artifact_model.dart',
  'agente/models/chat_message_model.dart',
  'agente/models/chat_session_model.dart',
  'agente/screens/agente_home_screen.dart',
  'agente/screens/chat_conversation_screen.dart',
  'agente/services/agente_supabase_service.dart',
  'agente/services/gemini_config.dart',
  'agente/services/gemini_service.dart',
  'agente/services/suite_rag_service.dart',
  'agente/theme/agente_colors.dart',
  'agente/viewmodels/agente_state.dart',
  'agente/widgets/action_proposal_card_view.dart',
  'agente/widgets/agente_chat_bottom_sheet.dart',
  'agente/widgets/artifact_card_view.dart',
  'agente/widgets/chat_message_bubble.dart',
  'agente/widgets/docked_launcher_chat.dart',
  'diario/dialogs/category_editor_dialog.dart',
  'diario/dialogs/contact_editor_dialog.dart',
  'diario/dialogs/entry_reader_dialog.dart',
  'diario/dialogs/quick_note_dialog.dart',
  'diario/diario.dart',
  'diario/models/diario_category.dart',
  'diario/models/diario_contact.dart',
  'diario/models/diario_entry.dart',
  'diario/models/diario_template.dart',
  'diario/models/mood_catalog.dart',
  'diario/models/mood_log.dart',
  'diario/models/mood_tag.dart',
  'diario/screens/animo_dashboard_screen.dart',
  'diario/screens/contact_detail_screen.dart',
  'diario/screens/diario_home_screen.dart',
  'diario/screens/diario_search_screen.dart',
  'diario/screens/entry_editor_dialog.dart',
  'diario/screens/template_manager_screen.dart',
  'diario/services/animo_supabase_service.dart',
  'diario/services/diario_supabase_service.dart',
  'diario/services/speech_recognition_service.dart',
  'diario/theme/diario_colors.dart',
  'diario/viewmodels/animo_state.dart',
  'diario/viewmodels/diario_state.dart',
  'diario/widgets/clipboard_image_helper.dart',
  'diario/widgets/clipboard_image_io.dart',
  'diario/widgets/contact_mood_section.dart',
  'diario/widgets/diario_image_helper.dart',
  'diario/widgets/diario_rich_editing.dart',
  'diario/widgets/mention_text_field.dart',
  'diario/widgets/mood_checkin_sheet.dart',
  'diario/widgets/mood_emotion_picker.dart',
  'diario/widgets/mood_log_tile.dart',
  'diario/widgets/mood_month_calendar.dart',
  'diario/widgets/mood_quick_bar.dart',
  'diario/widgets/mood_trend_chart.dart',
  'diario/widgets/personal_notes_view.dart',
  'habitos/dialogs/habit_detail_cli_dialog.dart',
  'habitos/dialogs/habit_terminal_editor_dialog.dart',
  'habitos/habitos.dart',
  'habitos/models/habit_log_model.dart',
  'habitos/models/habit_model.dart',
  'habitos/models/habit_stack_model.dart',
  'habitos/screens/habitos_home_screen.dart',
  'habitos/screens/habitos_metrics_screen.dart',
  'habitos/services/habitos_supabase_service.dart',
  'habitos/theme/habitos_terminal_theme.dart',
  'habitos/viewmodels/habitos_state.dart',
  'main.dart',
  'notas/dialogs/category_manager_dialog.dart',
  'notas/dialogs/note_reader_dialog.dart',
  'notas/models/note_block.dart',
  'notas/models/note_category.dart',
  'notas/models/note_item.dart',
  'notas/notas.dart',
  'notas/screens/notas_home_screen.dart',
  'notas/screens/note_editor_screen.dart',
  'notas/services/notas_supabase_service.dart',
  'notas/services/note_document_converter.dart',
  'notas/services/note_pdf_service.dart',
  'notas/theme/notas_colors.dart',
  'notas/viewmodels/notas_state.dart',
  'notas/widgets/note_block_widget.dart',
  'quebrado/dialogs/add_account_dialog.dart',
  'quebrado/dialogs/add_action_selection_sheet.dart',
  'quebrado/dialogs/add_category_dialog.dart',
  'quebrado/dialogs/add_exchange_dialog.dart',
  'quebrado/dialogs/add_recurring_payment_dialog.dart',
  'quebrado/dialogs/add_transaction_dialog.dart',
  'quebrado/dialogs/book_selector_dialog.dart',
  'quebrado/dialogs/calculator_dialog.dart',
  'quebrado/dialogs/cross_profile_transfer_dialog.dart',
  'quebrado/dialogs/day_actions_dialog.dart',
  'quebrado/dialogs/partial_payment_dialog.dart',
  'quebrado/dialogs/pending_confirmations_dialog.dart',
  'quebrado/dialogs/pin_setup_bottom_sheet.dart',
  'quebrado/dialogs/pin_verification_dialog.dart',
  'quebrado/dialogs/pocket_details_bottom_sheet.dart',
  'quebrado/dialogs/purchase_simulation_bottom_sheet.dart',
  'quebrado/dialogs/super_app_hub_sheet.dart',
  'quebrado/dialogs/transaction_detail_dialog.dart',
  'quebrado/dialogs/transfer_bank_dialog.dart',
  'quebrado/models/account.dart',
  'quebrado/models/currency_type.dart',
  'quebrado/models/exchange_rate_record.dart',
  'quebrado/models/market_item.dart',
  'quebrado/models/market_product.dart',
  'quebrado/models/market_shopping_list.dart',
  'quebrado/models/market_shopping_list_item.dart',
  'quebrado/models/market_store.dart',
  'quebrado/models/market_trip.dart',
  'quebrado/models/mobile_payment_recipient.dart',
  'quebrado/models/recurring_payment.dart',
  'quebrado/models/recurring_payment_partial.dart',
  'quebrado/models/saving_pocket.dart',
  'quebrado/models/timeline_day_summary.dart',
  'quebrado/models/timeline_event.dart',
  'quebrado/models/transaction.dart',
  'quebrado/models/transaction_category.dart',
  'quebrado/quebrado.dart',
  'quebrado/screens/account_management_screen.dart',
  'quebrado/screens/backup_management_screen.dart',
  'quebrado/screens/category_management_screen.dart',
  'quebrado/screens/dashboard_screen.dart',
  'quebrado/screens/main_screen.dart',
  'quebrado/screens/market_screen.dart',
  'quebrado/screens/market_shopping_list_screen.dart',
  'quebrado/screens/market_trip_screen.dart',
  'quebrado/screens/market_trip_store_screen.dart',
  'quebrado/screens/mobile_payment_recipient_screen.dart',
  'quebrado/screens/pockets_screen.dart',
  'quebrado/screens/rates_history_screen.dart',
  'quebrado/screens/settings_screen.dart',
  'quebrado/screens/timeline_screen.dart',
  'quebrado/screens/transactions_history_screen.dart',
  'quebrado/services/backup_service.dart',
  'quebrado/services/bcv_predictor.dart',
  'quebrado/services/biometric_service.dart',
  'quebrado/services/db_helper.dart',
  'quebrado/services/notification_manager.dart',
  'quebrado/services/rate_service.dart',
  'quebrado/services/supabase_config.dart',
  'quebrado/services/supabase_service.dart',
  'quebrado/theme/colors.dart',
  'quebrado/viewmodels/app_state.dart',
  'quebrado/widgets/add_market_item_bottom_sheet.dart',
  'quebrado/widgets/add_market_product_bottom_sheet.dart',
  'quebrado/widgets/add_market_store_bottom_sheet.dart',
  'quebrado/widgets/add_shopping_list_item_bottom_sheet.dart',
  'quebrado/widgets/animated_progress_bar.dart',
  'quebrado/widgets/claymorphic_background.dart',
  'quebrado/widgets/claymorphic_card.dart',
  'quebrado/widgets/currency_pill.dart',
  'quebrado/widgets/dashboard_charts_card.dart',
  'quebrado/widgets/exchange_suggestion_row.dart',
  'quebrado/widgets/helpers.dart',
  'quebrado/widgets/pocket_card.dart',
  'quebrado/widgets/product_details_bottom_sheet.dart',
  'quebrado/widgets/slide_to_confirm_button.dart',
  'quebrado/widgets/timeline_event_row.dart',
  'recordatorios/dialogs/command_palette_dialog.dart',
  'recordatorios/dialogs/covey_guide_dialog.dart',
  'recordatorios/dialogs/reminder_editor_dialog.dart',
  'recordatorios/dialogs/role_manager_dialog.dart',
  'recordatorios/dialogs/sunday_planning_wizard_dialog.dart',
  'recordatorios/models/covey_quadrant.dart',
  'recordatorios/models/reminder_model.dart',
  'recordatorios/models/role_model.dart',
  'recordatorios/models/weekly_plan_model.dart',
  'recordatorios/recordatorios.dart',
  'recordatorios/screens/reminders_home_screen.dart',
  'recordatorios/services/nlp_parser.dart',
  'recordatorios/services/reminders_supabase_service.dart',
  'recordatorios/theme/reminders_colors.dart',
  'recordatorios/viewmodels/reminders_state.dart',
  'recordatorios/widgets/covey_matrix_view.dart',
  'recordatorios/widgets/weekly_schedule_view.dart',
  'rich_editor/block_menu.dart',
  'rich_editor/custom_blocks.dart',
  'rich_editor/dictation.dart',
  'rich_editor/draft_banner.dart',
  'rich_editor/draft_store.dart',
  'rich_editor/escape_to_close.dart',
  'rich_editor/format_toolbar.dart',
  'rich_editor/mentions.dart',
  'rich_editor/plain_text.dart',
  'rich_editor/rich_document_editor.dart',
  'rich_editor/rich_document_viewer.dart',
  'rich_editor/rich_editor_colors.dart',
  'screens/app_launcher_screen.dart',
  'screens/launcher_action_hub_view.dart',
  'services/media_storage_service.dart',
  'services/notification_manager.dart',
  'services/supabase_config.dart',
  'services/supabase_service.dart',
  'services/web_splash.dart',
  'services/web_splash_stub.dart',
  'theme/colors.dart',
  'theme/ortiz_motion.dart',
  'theme/ortiz_space.dart',
  'theme/ortiz_theme.dart',
  'theme/ortiz_tokens.dart',
  'theme/ortiz_type.dart',
  'theme/suite_apps.dart',
  'viewmodels/app_state.dart',
  'widgets/desktop_command_center_view.dart',
  'widgets/responsive_breakpoints.dart',
  'widgets/responsive_sheet_helper.dart',
  'widgets/responsive_suite_scaffold.dart',
];

final _soloWeb = RegExp(
  r"^import '(dart:(html|js|js_interop|js_util|ui_web)|package:web/)",
  multiLine: true,
);

void main() {
  test('importa todo lib/ (la lista generada está al día)', () {
    final actuales = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_soloWeb.hasMatch(f.readAsStringSync()))
        .map((f) => f.path.replaceAll(r'\', '/').substring('lib/'.length))
        .toSet();
    final generados = _importados.toSet();
    final nuevos = actuales.difference(generados);
    final borrados = generados.difference(actuales);
    if (nuevos.isNotEmpty || borrados.isNotEmpty) {
      fail('Lista desactualizada: ejecuta ./tool/generate_all_imports_test.sh\n'
          'Nuevos: $nuevos\nBorrados: $borrados');
    }
  });
}
