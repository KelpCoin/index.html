@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_RevenueFactory.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0New_RevenueCell.ps1" ^
  -OfferName "Decision Dissection Sprint" ^
  -Silo "consulting" ^
  -OfferSummary "A 48-hour decision memo with ranked options and clear recommendation." ^
  -Audience "Solo operators and small teams" ^
  -PriceLogic "Flat 249 USD prepay before work starts." ^
  -DeliveryLogic "Collect brief, produce memo, and deliver markdown plus checksum proof within 48 hours."
endlocal
