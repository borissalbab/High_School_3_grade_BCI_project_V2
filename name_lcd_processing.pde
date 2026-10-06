import processing.serial.*;
import java.io.PrintWriter;

Serial tgamPort;
Serial arduinoPort;

int attention = 0;
int betaPower = 0;
int signalQuality = 200;

String userName = "";
String lastSentName = "";
boolean inputDone = false;
int sentLetters = 0;

int[] packet = new int[256];
int idx = 0;
boolean readingPacket = false;
boolean wasFocusing = false;

boolean missionDone = false;
int missionCompleteTime = 0;

PrintWriter logWriter;
int logCount = 0;

void setup() {
  size(600, 200);
  println("포트 목록:");
  printArray(Serial.list());

  for (String portName : Serial.list()) {
  if (portName.contains("COM") && tgamPort == null) {
    try {
      tgamPort = new Serial(this, portName, 57600);
      println("TGAM 연결: " + portName);
    } catch (Exception e) { }
  } else if (portName.contains("COM") && arduinoPort == null) {
    try {
      arduinoPort = new Serial(this, portName, 9600);
      println("Arduino 연결: " + portName);
    } catch (Exception e) { }
  }
}


  try {
    logWriter = createWriter("attention-log.txt");
  } catch (Exception e) {
    println("로그 파일 생성 실패: " + e.getMessage());
  }

  textSize(20);
  println("이름을 영어로 입력하세요:");

  if (arduinoPort != null) {
    arduinoPort.write("CLEAR\n");
    delay(200);
    arduinoPort.write("TITLE:ENTER NAME\n");
  }
}

void draw() {
  background(255);
  fill(0);

  if (!inputDone) {
    text("Your Name: " + userName, 50, 100);
    if (!userName.equals(lastSentName) && arduinoPort != null) {
      arduinoPort.write("LINE2:" + userName + "\n");
      lastSentName = userName;
    }
    return;
  }

  if (tgamPort != null) {
    while (tgamPort.available() > 0) {
      serialEvent(tgamPort);
    }
  }

  boolean isFocusing = isReliableAttention(attention, signalQuality, betaPower);

  if (!wasFocusing && isFocusing && sentLetters < userName.length()) {
    char nextChar = userName.charAt(sentLetters);
    if (arduinoPort != null) {
      arduinoPort.write("CHAR:" + nextChar + "\n");
      println("집중 시 전송된 문자: " + nextChar);
      sentLetters++;
    }
  }

  wasFocusing = isFocusing;

  if (!missionDone && sentLetters == userName.length()) {
    missionDone = true;
    missionCompleteTime = millis();
  }

  if (missionDone && millis() - missionCompleteTime >= 1000) {
    if (arduinoPort != null) {
      arduinoPort.write("TITLE:MISSION\n");
      delay(100);
      arduinoPort.write("LINE2:COMPLETE!!\n");
    }
    missionDone = false;
  }

  text("Attention: " + attention, 50, 160);
  text("Signal: " + signalQuality, 300, 160);
}

void keyPressed() {
  if (!inputDone) {
    if ((key == ENTER || key == RETURN) && userName.length() > 0) {
      inputDone = true;
      println("입력 완료: " + userName);
      if (arduinoPort != null) {
        arduinoPort.write("CLEAR\n");
        delay(200);
        arduinoPort.write("TITLE:FOCUSING...\n");
      }
    } else if (key == BACKSPACE && userName.length() > 0) {
      userName = userName.substring(0, userName.length() - 1);
    } else if (key >= 32 && key <= 126 && userName.length() < 16) {
      userName += key;
    }
  }
}

void serialEvent(Serial p) {
  int inByte = p.read() & 0xFF;

  if (!readingPacket) {
    if (inByte == 0xAA && packet[0] == 0xAA) {
      idx = 0;
      packet[idx++] = inByte;
      readingPacket = true;
    } else {
      packet[0] = inByte;
    }
  } else {
    if (idx < packet.length) {
      packet[idx++] = inByte;
      int payloadLength = packet[2];
      if (idx == 3 + payloadLength + 1) {
        parseTGAM(packet, 3, payloadLength);
        idx = 0;
        readingPacket = false;
      }
    } else {
      forceRecoverFromCorruptedPacket();
    }
  }
}

void parseTGAM(int[] data, int start, int length) {
  int i = start;
  boolean hasAttention = false;
  boolean hasBeta = false;
  boolean hasSignal = false;

  int tempAttention = attention;
  int tempBeta = betaPower;
  int tempSignal = signalQuality;

  while (i < start + length) {
    int code = data[i++];
    if (code == 0x02) {
      tempSignal = data[i++];
      hasSignal = true;
    } else if (code == 0x04) {
      int raw = data[i++];
      if (raw >= 0 && raw <= 100) {
        tempAttention = raw;
        hasAttention = true;
      } else {
        println("⚠ 잘못된 attention 값 → 패킷 복구 시도: " + raw);
        forceRecoverFromCorruptedPacket();
        return;
      }
    } else if (code == 0x83) {
      int len = data[i++];
      if (len == 24) {
        i += 12;
        int lowBeta = (data[i++] << 16) | (data[i++] << 8) | data[i++];
        int highBeta = (data[i++] << 16) | (data[i++] << 8) | data[i++];
        int totalBeta = lowBeta + highBeta;
        if (totalBeta <= 1000000) {
          tempBeta = totalBeta;
          hasBeta = true;
          println("Beta Power: " + tempBeta);
        } else {
          println("⚠ 비정상 betaPower 무시됨: " + totalBeta);
          return;
        }
        i += 24 - 18;
      } else {
        i += len;
      }
    } else if (code >= 0x80) {
      int len = data[i++];
      i += len;
    } else {
      i++;
    }
  }

  if (hasAttention && hasBeta && hasSignal) {
    attention = tempAttention;
    betaPower = tempBeta;
    signalQuality = tempSignal;

    if (isReliableAttention(attention, signalQuality, betaPower) && logWriter != null) {
      String timestamp = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
      logWriter.println(timestamp + " | ATT: " + attention + " | BETA: " + betaPower + " | SIG: " + signalQuality);
      logCount++;
      if (logCount % 10 == 0) logWriter.flush();
    }
  }
}

boolean isReliableAttention(int att, int signalQ, int beta) {
  return signalQ <= 50 && att >= 0 && att <= 100 && abs(att - scaleBetaToAttention(beta)) < 40;
}

int scaleBetaToAttention(int betaPower) {
  return constrain((int)(betaPower / 600.0), 0, 100);
}

void forceRecoverFromCorruptedPacket() {
  for (int j = 1; j < idx - 1; j++) {
    if (packet[j] == 0xAA && packet[j + 1] == 0xAA) {
      packet[0] = 0xAA;
      packet[1] = 0xAA;
      idx = 2;
      readingPacket = true;
      return;
    }
  }
  idx = 0;
  readingPacket = false;
}
