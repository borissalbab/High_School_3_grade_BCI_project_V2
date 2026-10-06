#include <Wire.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
String input = "";
int cursorPos = 0;

void setup() {
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("attention...");
}

void loop() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      handleCommand(input);
      input = "";
    } else {
      input += c;
    }
  }
}

void handleCommand(String cmd) {
  cmd.trim();

  // LCD 전체 초기화
  if (cmd == "CLEAR") {
    lcd.clear();
    delay(100);
    cursorPos = 0;
    lcd.setCursor(0, 0);
    lcd.print("attention...");
    lcd.setCursor(0, 1);
  }

  // 1행 텍스트 출력
  else if (cmd.startsWith("TITLE:") && cmd.length() > 6) {
    lcd.setCursor(0, 0);
    lcd.print("                ");
    lcd.setCursor(0, 0);
    lcd.print(cmd.substring(6));
  }

  // 2행 텍스트 전체 출력
  else if (cmd.startsWith("LINE2:") && cmd.length() > 7) {
    lcd.setCursor(0, 1);
    lcd.print("                ");
    lcd.setCursor(0, 1);
    String content = cmd.substring(6);
    lcd.print(content);
    cursorPos = content.length();
  }

  // 2행에 한 글자씩 추가 출력
  else if (cmd.startsWith("CHAR:") && cmd.length() >= 6) {
    char letter = cmd.charAt(5);
    if (cursorPos < 16) {
      lcd.setCursor(cursorPos, 1);
      lcd.print(letter);
      cursorPos++;
    }
  }
}
