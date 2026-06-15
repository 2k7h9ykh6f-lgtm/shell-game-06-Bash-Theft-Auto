#!/bin/bash
# =============================================================================
# BTA Language File: Russian (Частичный перевод / Partial)
# =============================================================================
# This is a PARTIAL translation. Missing keys will fall back to English (LANG_EN).
# In debug mode, missing keys are logged to bta_debug.log.
# =============================================================================

declare -gA LANG_RU=(

    # --- General / Common ---
    ["press_enter"]="Нажмите Enter..."
    ["press_enter_continue"]="Нажмите Enter для продолжения..."
    ["press_enter_return"]="Нажмите Enter для возврата..."
    ["press_enter_hospital"]="Нажмите Enter чтобы отправиться в больницу..."
    ["enter_choice"]="Введите ваш выбор: "
    ["choice"]="Выбор: "
    ["confirm_yn"]="Подтвердить? (д/н): "
    ["invalid_choice"]="Неверный выбор."
    ["invalid_amount"]="Неверная сумма."
    ["not_enough_cash"]="Недостаточно денег."
    ["yes"]="д"
    ["no"]="н"

    # --- Header / UI Labels ---
    ["game_title"]="Bash Theft Auto"
    ["label_day"]="День"
    ["label_time"]="Время"
    ["label_player"]="Игрок"
    ["label_location"]="Место"
    ["label_cash"]="Деньги"
    ["label_health"]="Здоровье"
    ["label_armor"]="Броня"
    ["label_wanted"]="Розыск"
    ["label_gang"]="Банда"
    ["label_rank"]="Ранг"
    ["label_respect"]="Уважение"
    ["label_district_heat"]="Накал района"
    ["label_city_rep"]="Репутация"
    ["armor_equipped"]="Надета"
    ["armor_none"]="Нет"

    # --- Main Menu ---
    ["menu_title"]="--- Действия ---"
    ["menu_travel"]="Путешествовать"
    ["menu_buy_guns"]="Купить оружие"
    ["menu_buy_vehicle"]="Купить транспорт"
    ["menu_inventory"]="Инвентарь"
    ["menu_work"]="Работа"
    ["menu_buy_drugs"]="Купить наркотики"
    ["menu_sell_drugs"]="Продать наркотики"
    ["menu_crime"]="Преступление"
    ["menu_gang"]="Банда"
    ["menu_perks"]="Навыки"
    ["menu_save"]="Сохранить"
    ["menu_load"]="Загрузить"
    ["menu_about"]="Об игре"
    ["menu_exit"]="Выход"

    # --- Death / Wasted ---
    ["wasted"]="П О Т Р А Ч Е Н О"
    ["death_message"]="Вы потеряли сознание от полученных ран..."
    ["death_respect_loss"]="Вы потеряли %d Уважения за то, что вас уложили."

    # --- Respect / Perks ---
    ["respect_gained"]="Вы получили %d Уважения."
    ["perk_point_earned"]="*** ПОЛУЧЕНО ОЧКО НАВЫКА! ***"
    ["perk_points_info"]="Вы получили %d очко(ов) навыка. Теперь у вас %d."
    ["rank_up"]="*** ПОВЫШЕНИЕ! ***"
    ["rank_up_msg"]="Вы повышены до %s!"

    # --- City Reputation ---
    ["city_rep_title"]="--- Репутация в городе ---"
    ["city_rep_desc"]="Ваша репутация определяет бонусы к зарплате, скидки в магазинах и реакции NPC."
    ["city_rep_legend"]="Легенда"
    ["city_rep_known"]="Известный"
    ["city_rep_respected"]="Уважаемый"
    ["city_rep_noticed"]="Замеченный"
    ["city_rep_unknown"]="Неизвестный"

    # --- Loan Shark ---
    ["loan_title"]="--- Лавка Винни ---"
    ["loan_motto"]="Деньги когда нужны. Боль когда не платишь."
    ["loan_current"]="Текущий заём"
    ["loan_interest"]="Проценты"
    ["loan_take"]="Взять заём"
    ["loan_repay"]="Вернуть заём"
    ["loan_back"]="Назад"
    ["loan_outstanding"]="У вас уже есть непогашенный заём. Сначала верните его."

    # --- Police Encounter ---
    ["police_title"]="--- Встреча с полицией! ---"
    ["police_run"]="Попытаться убежать"
    ["police_surrender"]="Сдаться"
    ["police_bribe"]="Дать взятку"
    ["police_run_success"]="Вы юркнули в переулок..."
    ["police_surrender_msg"]="Вы подняли руки..."

    # --- Game Start ---
    ["welcome"]="Добро пожаловать в Bash Theft Auto!"
    ["enter_name"]="Введите имя вашего персонажа: "
    ["starting_msg"]="Начинаем ваш криминальный путь в Лос-Сантосе..."

    # --- Save / Load ---
    ["save_title"]="--- Сохранение ---"
    ["load_title"]="--- Загрузка ---"
    ["save_success"]="Игра успешно сохранена!"
    ["load_success"]="Игра успешно загружена!"
    ["save_not_found"]="Файл сохранения не найден."

    # --- About ---
    ["about_title"]="Об игре"
    ["about_thanks"]="Спасибо за игру!"

    # --- Cleanup ---
    ["cleanup_msg"]="Очистка и выход..."
    ["cleanup_complete"]="Очистка завершена. До свидания."

    # NOTE: The following keys are intentionally MISSING to demonstrate fallback:
    #   travel_title, travel_select, travel_already_there, travel_cost
    #   work_title, work_select_job, work_no_jobs, work_earned
    #   crime_title, crime_select, crime_success, crime_failed, crime_wanted_increase
    #   inventory_title, inventory_guns, inventory_items, inventory_drugs, inventory_empty
    #   market_title, market_buy, market_sell, market_price, market_quantity
    #   auction_title, auction_bid, auction_outbid, auction_won
    #   enforcer_title, enforcer_fight, enforcer_flee
    #   city_rep_benefits, loan_invalid_amount, overwrite_save
    #   stopping_music
    # These will automatically fall back to English at runtime.
)
