import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

void main() {
  runApp(MaterialApp(
    title: '돌파고',
    home: MyHomePage(),
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
  ));
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const int CMAX = 11; // number of attempts + 1
  static const int PMAX = 6; // number of probs (25, 35, 45, 55, 65, 75)
  // dynamic dp[CMAX][CMAX][CMAX][PMAX][CMAX][CMAX][CMAX];
  List<dynamic> dp = List.filled(pow(CMAX, 6) * PMAX, 0.0); // initialized to 0

  // History of attempts
  // first value means ability number (1~3)
  // second value means success or fail (0: fail, 1: success)
  // abil1 success, abil2 fail => [[1, 1], [2, 0]]
  List seq = []; // 세공 기록

  List<int> savedGoal = [7, 7, 4]; // 기본 목표 각인
  List<int> goal = [7, 7, 4]; // 목표 각인(자동 변환 포함)

  int numAttempts = 10; // 시도 횟수 개수(3티어 유물:10,전설:9,영웅:8,희귀:7)
  bool isAutoAdjust = true;
  String info = "확률 계산 중...";
  int curProb = 75;
  var rand = new Random();

  // List attemptsList = [10, 9, 8, 7];
  // List<bool> isSelectedList = [true, false, false, false];

  // \u25C7:◇, \u25C6:◆
  List<String> abilitySym = List.filled(3, "◇ " * 10);
  List<double> abilityProb = [0.0, 0.0, 0.0];
  List<String> abilityText = ['', '', ''];

  String goalStr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('돌파고'),
      ),
      body: Container(
        padding: EdgeInsets.only(left: 40, right: 20, top: 30),
        child: Column(
          children: [
            Text("$info"),
            Row(
              children: [
                Text("      $curProb" + "%      "),
                OutlinedButton(onPressed: reset, child: Text('리셋')),
                SizedBox(width: 20,),
                OutlinedButton(onPressed: undo, child: Text('취소')),
                // Text("${toPercent(cur_prob)}   "),
              ],
            ),
            // 세공 칸 수 조절
            // ToggleButtons(
            //   direction: Axis.horizontal,
            //   isSelected: isSelectedList,
            //   onPressed: (int clickedIndex) {
            //     setState(() {
            //       for (int buttonIndex = 0;
            //           buttonIndex < isSelectedList.length;
            //           buttonIndex++) {
            //         isSelectedList[buttonIndex] = (buttonIndex == clickedIndex);
            //       }
            //
            //       print(isSelectedList.toString());
            //       for (int i = 0; i < 3; i++) {
            //         if (goal[i] > attemptsList[clickedIndex]) {
            //           goal[i] = attemptsList[clickedIndex];
            //         }
            //       }
            //       numAttempts = attemptsList[clickedIndex];
            //       changeAttempt();
            //     });
            //   },
            //   children: <Widget>[
            //     Text('${attemptsList[0]}'),
            //     Text('${attemptsList[1]}'),
            //     Text('${attemptsList[2]}'),
            //     Text('${attemptsList[3]}'),
            //   ],
            // ),
            // 각인별 전체 프레임
            frame(1),
            frame(2),
            frame(3),
            Row(
              children: [
                Text('목표 각인 : $goalStr    '),
                // 목표 각인 선택 드롭다운
                Text('목표 각인 자동 조정'),
                Switch(
                  value: isAutoAdjust,
                  onChanged: (value) {
                    setState(() {
                      isAutoAdjust = !isAutoAdjust;
                      print("isAutoAdjust : $isAutoAdjust");
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                // 목표 세공 조절
                savedGoalButtons(1),
                savedGoalButtons(2),
                savedGoalButtons(3),
                // 세공 횟수 조절
                DropdownButtonHideUnderline(
                    child: DropdownButton(
                  value: numAttempts,
                  items: [10, 9, 8, 7].map(
                    (value) {
                      return DropdownMenuItem(
                          value: value,
                          child: Text(
                            "$value",
                          ));
                    },
                  ).toList(),
                  onChanged: (value) {
                    print(value);
                    setState(() {
                      for (int i = 0; i < 3; i++) {
                        if (goal[i] > value) {
                          goal[i] = value;
                        }
                      }
                      numAttempts = value;
                      changeAttempt();
                    });
                  },
                )),
              ],
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      info = '확률 계산 중...';
    });

    calDp().then((_) {
      print('finish set dp');
      setState(() {
        info = '확률 계산 완료';
        goalStr = '${goal[0]}/${goal[1]}/${goal[2]}';

        changeAttempt();
      });
    });
  }

  Future calDp() async {
    // ByteData data = await rootBundle.load('assets/stone2.txt');
    // String str = utf8.decode(data.buffer.asUint8List());

    print('start calDp()');
    String str;
    str = utf8.decode(
        (await rootBundle.load('assets/stone2.txt')).buffer.asUint8List());
    dp = str.split(',').map(double.parse).toList();
    return;
  }

  // 각인 별 위젯
  Widget frame(int idx) {
    String text;

    switch (idx) {
      case 1:
        text = "증가각인1";
        break;
      case 2:
        text = "증가각인2";
        break;
      case 3:
        text = "감소각인";
        break;
    }

    return Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("$text      "),
                Text("${abilityProb[idx - 1].toStringAsFixed(5)}%      "),
                Text("${abilityText[idx - 1]}"),
              ],
            ),
            SizedBox(height: 10,),
            Text(
              "${abilitySym[idx - 1]}",
              style: TextStyle(fontFamily: 'Noto_Sans_KR'),
            ),
            SizedBox(height: 10,),
            Row(mainAxisSize: MainAxisSize.max,mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                    onPressed: () => doAttempt(idx, 1), child: Text('성공')),
                OutlinedButton(
                    onPressed: () => doAttempt(idx, 0), child: Text('실패')),
                OutlinedButton(
                    onPressed: () {
                      int r = rand.nextInt(100);
                      print("r : $r   curProb : $curProb");
                      if (r < curProb)
                        doAttempt(idx, 1);
                      else
                        doAttempt(idx, 0);
                    },
                    child: Text('세공')),
              ],
            ),
          ],
        ));
  }

  // 목표 각인 버튼
  Widget savedGoalButtons(int idx) {
    List<int> attempts = List<int>.generate(
        numAttempts + 1, (int index) => numAttempts - index,
        growable: false);

    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          width: 50,
          child: DropdownButtonHideUnderline(
              child: DropdownButton(
            value: savedGoal[idx - 1],
            items: attempts.map(
              (value) {
                return DropdownMenuItem(
                    value: value,
                    child: Text(
                      "$value",
                    ));
              },
            ).toList(),
            onChanged: (value) {
              print(value);
              setState(() {
                savedGoal[idx - 1] = value;
                goal[idx - 1] = value;
              });
              adjustGoal();
            },
          )),
        ));

    // List<bool> isSelected = List<bool>.generate(attempts.length, (_) => false);
    //
    // isSelected[goal[idx - 1]] = true;
    //
    // return ToggleButtons(
    //   isSelected: isSelected,
    //   direction: Axis.vertical,
    //   onPressed: (int index) {
    //     setState(() {
    //       goal[idx - 1] = numAttempts - index;
    //     });
    //   },
    //   children: goalButtonLayout(attempts),
    // );
  }

  // List<Widget> goalButtonLayout(List<int> attempts) {
  //   List<Text> buttons = List<Text>.generate(
  //       attempts.length, (int index) => Text('${attempts[index]}'),
  //       growable: false);
  //   return buttons;
  // }

  // 시도 횟수 선택
  void changeAttempt() {
    for (int i = 0; i <= 2; i++) {
      setState(() {
        abilitySym[i] = "◇   " * numAttempts;
      });
      // print(ability_sym[i]);
    }
    reset();
    adjustGoal();
  }

  void calcProb() {
    int p = cal_p_from_seq();
    curProb = (decodeP(p) * 100).toInt();

    List idx1 = cal_idx_from_seq(1);
    List idx2 = cal_idx_from_seq(2);
    List idx3 = cal_idx_from_seq(3);
    List<double> prob = [0, 0, 0];
    prob[0] =
        calProb1Safe(idx1[0], idx2[0], idx3[0], p, idx1[1], idx2[1], idx3[1]);
    prob[1] =
        calProb2Safe(idx1[0], idx2[0], idx3[0], p, idx1[1], idx2[1], idx3[1]);
    prob[2] =
        calProb3Safe(idx1[0], idx2[0], idx3[0], p, idx1[1], idx2[1], idx3[1]);
    double maxProb = max<double>(max<double>(prob[0], prob[1]), prob[2]);

    setState(() {
      abilitySym[0] = build_sym_from_seq(1);
      abilitySym[1] = build_sym_from_seq(2);
      abilitySym[2] = build_sym_from_seq(3);

      abilityProb[0] = prob[0] * 100;
      abilityProb[1] = prob[1] * 100;
      abilityProb[2] = prob[2] * 100;
      // print(ability_sym.toString() + ability_prob.toString());

      abilityText[0] = prob[0] == maxProb && prob[0] != 0 ? "추천!" : "";
      abilityText[1] = prob[1] == maxProb && prob[1] != 0 ? "추천!" : "";
      abilityText[2] = prob[2] == maxProb && prob[2] != 0 ? "추천!" : "";

      goalStr = '${goal[0]}/${goal[1]}/${goal[2]}';
    });
  }

  int getIdx(a, b, c, p, d, e, f) {
    return (((((a * CMAX + b) * CMAX + c) * PMAX + p) * CMAX + d) * CMAX + e) *
            CMAX +
        f;
  }

  double decodeP(p) {
    return 0.25 + p * 0.1;
  }

  double calProb1(a, b, c, p, d, e, f) {
    return a > 0
        ? decodeP(p) *
                dp[getIdx(a - 1, b, c, max<int>(p - 1, 0), max<int>(d - 1, 0),
                    e, f)] +
            (1 - decodeP(p)) *
                dp[getIdx(a - 1, b, c, min<int>(p + 1, PMAX - 1), d, e, f)]
        : 0;
  }

  double calProb1Safe(a, b, c, p, d, e, f) {
    if (f < 0) return 0;
    d = max<int>(d, 0);
    e = max<int>(e, 0);
    return calProb1(a, b, c, p, d, e, f);
  }

  double calProb2(a, b, c, p, d, e, f) {
    return b > 0
        ? decodeP(p) *
                dp[getIdx(a, b - 1, c, max<int>(p - 1, 0), d,
                    max<int>(e - 1, 0), f)] +
            (1 - decodeP(p)) *
                dp[getIdx(a, b - 1, c, min<int>(p + 1, PMAX - 1), d, e, f)]
        : 0;
  }

  double calProb2Safe(a, b, c, p, d, e, f) {
    if (f < 0) return 0;
    d = max<int>(d, 0);
    e = max<int>(e, 0);
    return calProb2(a, b, c, p, d, e, f);
  }

  double calProb3(a, b, c, p, d, e, f) {
    return c > 0
        ? (f == 0
                ? 0
                : decodeP(p) *
                    dp[getIdx(a, b, c - 1, max<int>(p - 1, 0), d, e, f - 1)]) +
            (1 - decodeP(p)) *
                dp[getIdx(a, b, c - 1, min<int>(p + 1, PMAX - 1), d, e, f)]
        : 0;
  }

  double calProb3Safe(a, b, c, p, d, e, f) {
    if (f < 0) return 0;
    d = max<int>(d, 0);
    e = max<int>(e, 0);
    return calProb3(a, b, c, p, d, e, f);
  }

  int cal_p_from_seq() {
    dynamic p = PMAX - 1;
    seq.forEach((attempt) {
      if (attempt[1] == 0) {
        p = min<int>(p + 1, PMAX - 1);
      } else {
        p = max<int>(p - 1, 0);
      }
    });
    return p;
  }

  String build_sym_from_seq(idx) {
    dynamic sym = "", cnt = 0;
    seq.forEach((attempt) {
      if (attempt[0] == idx) {
        sym += attempt[1] == 0 ? "×   " : "◆   ";
        ++cnt;
      }
    });
    sym += "◇   " * (numAttempts - cnt);
    return sym;
  }

  List cal_idx_from_seq(idx) {
    int a = numAttempts, d = goal[idx - 1];
    seq.forEach((attempt) {
      if (attempt[0] == idx) {
        a--;
        if (attempt[1] == 1) {
          d--;
        }
      }
    });
    return [a, d]; // 남은 칸, 목표까지 필요한 칸
  }

  String toPercent(x) {
    // x *= 100;
    String str = x == 0
        ? "0%"
        : (x * (max<double>(2 - (log(x) / log(10)).floorToDouble(), 0)))
                .toString() +
            "%";
    return str;
  }

// 세공 시도
  void doAttempt(idx, result) {
    int cnt = 0;
    seq.forEach((attempt) {
      // print("${attempt[0]}   $idx");
      if (attempt[0] == idx) {
        ++cnt;
      }
    });
    if (cnt < numAttempts) {
      seq.add([idx, result]);
    }
    adjustGoal();
    // setState(() {
    //   calc_prob();
    // });
    print("seq : $seq");
  }

  // 세공 취소
  void undo() {
    if (seq.length > 0) seq.removeLast();
    adjustGoal();
  }

  // 세공 초기화
  void reset() {
    seq = [];
    goal = savedGoal.toList();
    print(savedGoal.toString());
    adjustGoal();
  }

  void adjustGoal() {
    if (isAutoAdjust == false) {
      calcProb();
      return;
    }

    for (int i = 0; i < 3; i++) {
      List idx = cal_idx_from_seq(i + 1);
      if (idx[0] < idx[1]) {
        goal[i] -= idx[1] - idx[0];
      }
      if (savedGoal[i] > goal[i] && idx[0] > idx[1]) {
        goal[i] -= idx[1] - idx[0];
      }
    }
    calcProb();
  }
}
