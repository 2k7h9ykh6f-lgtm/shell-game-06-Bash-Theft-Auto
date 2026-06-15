#!/bin/bash
# =============================================================================
# BTA Language File: English (Default)
# =============================================================================
# This file defines the default English strings for the game.
# All other language files fall back to these values when a key is missing.
#
# To add new translatable strings:
#   1. Add a key here with the English value
#   2. Use  _("key")  in the game code
#   3. Add the translation to other lang/*.sh files
# =============================================================================

declare -gA LANG_EN=(

    # --- General / Common ---
    ["press_enter"]="Press Enter..."
    ["press_enter_continue"]="Press Enter to continue..."
    ["press_enter_return"]="Press Enter to return..."
    ["press_enter_hospital"]="Press Enter to go to the hospital..."
    ["enter_choice"]="Enter your choice: "
    ["choice"]="Choice: "
    ["confirm_yn"]="Confirm? (y/n): "
    ["invalid_choice"]="Invalid choice."
    ["invalid_amount"]="Invalid amount."
    ["not_enough_cash"]="Not enough cash."
    ["yes"]="y"
    ["no"]="n"

    # --- Header / UI Labels ---
    ["game_title"]="Bash Theft Auto"
    ["label_day"]="Day"
    ["label_time"]="Time"
    ["label_player"]="Player"
    ["label_location"]="Location"
    ["label_cash"]="Cash"
    ["label_health"]="Health"
    ["label_armor"]="Armor"
    ["label_wanted"]="Wanted"
    ["label_gang"]="Gang"
    ["label_rank"]="Rank"
    ["label_respect"]="Respect"
    ["label_district_heat"]="District Heat"
    ["label_city_rep"]="City Rep"
    ["armor_equipped"]="Equipped"
    ["armor_none"]="None"

    # --- Main Menu ---
    ["menu_title"]="--- Actions ---"
    ["menu_travel"]="Travel"
    ["menu_buy_guns"]="Buy Guns"
    ["menu_buy_vehicle"]="Buy Vehicle"
    ["menu_inventory"]="Inventory"
    ["menu_work"]="Work"
    ["menu_buy_drugs"]="Buy Drugs"
    ["menu_sell_drugs"]="Sell Drugs"
    ["menu_crime"]="Crime"
    ["menu_gang"]="Gang"
    ["menu_perks"]="Perks"
    ["menu_save"]="Save Game"
    ["menu_load"]="Load Game"
    ["menu_about"]="About"
    ["menu_exit"]="Exit"

    # --- Death / Wasted ---
    ["wasted"]="W A S T E D"
    ["death_message"]="You collapsed from your injuries..."
    ["death_respect_loss"]="You lost %d Respect for being taken down."

    # --- Respect / Perks ---
    ["respect_gained"]="You gained %d Respect."
    ["perk_point_earned"]="*** PERK POINT EARNED! ***"
    ["perk_points_info"]="You gained %d Perk Point(s). You now have %d."
    ["rank_up"]="*** RANK UP! ***"
    ["rank_up_msg"]="You have been promoted to %s!"

    # --- City Reputation ---
    ["city_rep_title"]="--- City Reputation ---"
    ["city_rep_desc"]="Your reputation determines job pay bonuses, shop discounts, and NPC reactions."
    ["city_rep_legend"]="Legend"
    ["city_rep_known"]="Known"
    ["city_rep_respected"]="Respected"
    ["city_rep_noticed"]="Noticed"
    ["city_rep_unknown"]="Unknown"
    ["city_rep_benefits"]="Benefits: 20+ = +5% job pay | 40+ = shop discount | 60+ = contact unlock hints | 80+ = feared (crime success boost)"

    # --- Loan Shark ---
    ["loan_title"]="--- Vinnie's Loan Shop ---"
    ["loan_motto"]="Money when you need it. Pain when you don't pay."
    ["loan_current"]="Current Loan"
    ["loan_interest"]="Interest"
    ["loan_take"]="Take a Loan"
    ["loan_repay"]="Repay Loan"
    ["loan_back"]="Back"
    ["loan_outstanding"]="You already have an outstanding loan. Repay it first."
    ["loan_invalid_amount"]="Invalid amount or not enough cash."

    # --- Police Encounter ---
    ["police_title"]="--- Police Encounter! ---"
    ["police_run"]="Try to run"
    ["police_surrender"]="Surrender"
    ["police_bribe"]="Bribe"
    ["police_run_success"]="You bolt down the alley..."
    ["police_surrender_msg"]="You put your hands up..."

    # --- Loan Enforcer ---
    ["enforcer_title"]="--- Loan Enforcer Visit ---"
    ["enforcer_fight"]="Fight the enforcers"
    ["enforcer_flee"]="Slip away"

    # --- Black Market Auction ---
    ["auction_title"]="--- Underground Auction House ---"
    ["auction_bid"]="Your bid: $"
    ["auction_outbid"]="Outbid! Try again? (Enter to go back to menu)"
    ["auction_won"]="You paid $%d for: %s"

    # --- Game Start ---
    ["welcome"]="Welcome to Bash Theft Auto!"
    ["enter_name"]="Enter your character's name: "
    ["starting_msg"]="Starting your criminal journey in Los Santos..."

    # --- Save / Load ---
    ["save_title"]="--- Save Game ---"
    ["load_title"]="--- Load Game ---"
    ["save_success"]="Game saved successfully!"
    ["load_success"]="Game loaded successfully!"
    ["save_not_found"]="No save file found."
    ["overwrite_save"]="Overwrite existing save? (y/n): "

    # --- Travel ---
    ["travel_title"]="--- Travel ---"
    ["travel_select"]="Select destination:"
    ["travel_already_there"]="You are already in %s."
    ["travel_cost"]="Travel to %s costs $%d."

    # --- Work ---
    ["work_title"]="--- Work ---"
    ["work_select_job"]="Select a job:"
    ["work_no_jobs"]="No jobs available right now."
    ["work_earned"]="You earned $%d from your job."

    # --- Crime ---
    ["crime_title"]="--- Crime ---"
    ["crime_select"]="Select a crime:"
    ["crime_success"]="Crime successful! You earned $%d."
    ["crime_failed"]="Crime failed! You were caught."
    ["crime_wanted_increase"]="Wanted level increased!"

    # --- Inventory ---
    ["inventory_title"]="--- Inventory ---"
    ["inventory_guns"]="Guns"
    ["inventory_items"]="Items"
    ["inventory_drugs"]="Drugs"
    ["inventory_empty"]="Your inventory is empty."
    ["inventory_use"]="Use"
    ["inventory_drop"]="Drop"

    # --- Market / Drugs ---
    ["market_title"]="--- Black Market ---"
    ["market_buy"]="Buy"
    ["market_sell"]="Sell"
    ["market_price"]="Price"
    ["market_quantity"]="Quantity"

    # --- About ---
    ["about_title"]="About"
    ["about_thanks"]="Thank you for playing!"
    ["about_music"]="Music and some SFX © 2024 by stuffbymax - Martin Petik"
    ["about_license"]="Licensed under CC BY 4.0"
    ["about_code"]="Full game code is licensed under the MIT License."

    # --- Cleanup ---
    ["cleanup_msg"]="Cleaning up and exiting..."
    ["stopping_music"]="Stopping music (PID: %d)..."
    ["cleanup_complete"]="Cleanup complete. Goodbye."
)
