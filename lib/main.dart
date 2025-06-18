import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MathMonsterApp());
}

class MathMonsterApp extends StatelessWidget {
  const MathMonsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Monster Battle',
      theme: ThemeData(primarySwatch: Colors.deepPurple, fontFamily: 'Arial'),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: kDebugMode ? 'Teste' : '',
  );
  final TextEditingController _codeController = TextEditingController(
    text: kDebugMode ? '1234' : '',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple[900]!, Colors.purple[400]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '⚔️ MATH RUSH ⚔️',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 40),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Digite seu nome',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Código Unico',
                        counterText: '',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.isEmpty ||
                              _codeController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Por favor, preencha todos os campos.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => GameScreen(
                                    playerName: _nameController.text.trim(),
                                    playerCode: _codeController.text.trim(),
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          '🔥 INICIAR JOGO',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RankingScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          '🏆 RANKING',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final String playerName;
  final String playerCode;

  const GameScreen({
    super.key,
    required this.playerName,
    required this.playerCode,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

enum GamePhase {
  monsterSelection,
  battleQuestions,
  attackExecution,
  monsterAttack,
  roundComplete,
}

int armorPoints = 0;
int playerHealth = 100;
int maxHealth = 100;
int score = 0;
int round = 1;
bool isBossRound = false;

bool isGameOver = false;

GamePhase currentPhase = GamePhase.monsterSelection;
List<Monster> allMonsters = [];
List<Monster> selectedMonsters = [];
List<MathProblem> battleQuestions = [];
int currentQuestionIndex = 0;
int attackPower = 0;
int correctAnswers = 0;

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  Timer? questionTimer;
  int timeLeft = maxTime;

  static const int maxTime = 60;

  late AnimationController _damageAnimation;
  late AnimationController _healAnimation;
  late AnimationController _attackAnimation;

  bool displayCorrectButton = false;

  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _damageAnimation = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _healAnimation = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _attackAnimation = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _startNewRound();
  }

  @override
  void dispose() {
    _damageAnimation.dispose();
    _healAnimation.dispose();
    _attackAnimation.dispose();
    questionTimer?.cancel();
    super.dispose();
  }

  void _startNewRound() {
    setState(() {
      isBossRound = round % 5 == 0;
      currentPhase = GamePhase.monsterSelection;
      selectedMonsters.clear();
      battleQuestions.clear();
      currentQuestionIndex = 0;
      attackPower = 0;
      correctAnswers = 0;

      if (round % 5 == 1 && round > 1) {
        // Cura a cada 5 rounds
        playerHealth = min(maxHealth, playerHealth + 30);
        _healAnimation.forward().then((_) => _healAnimation.reset());
      }

      _generateMonsters();
    });
  }

  void _generateMonsters() {
    allMonsters.clear();

    if (isBossRound) {
      allMonsters.add(Monster.boss(round));
    } else {
      int monsterCount = 3 + (round ~/ 2);

      allMonsters.addAll(Monster.normal(round, monsterCount));
    }
  }

  void _selectMonster(Monster monster) {
    final limit = (7 - (round - (round % 10)) / 10).clamp(2, 999).toInt();

    setState(() {
      if (selectedMonsters.contains(monster)) {
        selectedMonsters.remove(monster);
      } else if (selectedMonsters.length < limit) {
        selectedMonsters.add(monster);
      }
    });
  }

  void _startBattle() {
    if (selectedMonsters.isEmpty) return;

    setState(() {
      currentPhase = GamePhase.battleQuestions;
      battleQuestions.clear();
      currentQuestionIndex = 0;
      attackPower = 0;
      correctAnswers = 0;
      timeLeft = maxTime + selectedMonsters.length * 5;
    });

    // Gerar perguntas baseadas no número de monstros selecionados
    int questionCount = selectedMonsters.length * 30;
    int difficulty = selectedMonsters.length + (round ~/ 1);

    for (int i = 0; i < questionCount; i++) {
      battleQuestions.add(
        MathProblem.generate(difficulty + i, selectedMonsters),
      );
    }

    _showNextQuestion();
  }

  void _showNextQuestion() {
    if (currentQuestionIndex >= battleQuestions.length) {
      _executeAttack();
      return;
    }

    // setState(() {
    //   timeLeft = 15; // 15 segundos por pergunta
    // });

    _startTimer();
  }

  void _startTimer() {
    questionTimer?.cancel();
    questionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        _timeUp();
      }
    });
  }

  void _timeUp() {
    if (currentPhase != GamePhase.battleQuestions) {
      return;
    }
    _executeAttack();
  }

  Future<void> _answerQuestion(int selectedAnswer) async {
    questionTimer?.cancel();

    MathProblem currentProblem = battleQuestions[currentQuestionIndex];
    bool isCorrect = selectedAnswer == currentProblem.correctOption;

    setState(() {
      displayCorrectButton = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      displayCorrectButton = false;
    });

    if (isCorrect) {
      setState(() {
        correctAnswers++;

        attackPower +=
            (20 + (correctAnswers * 5)) *
            selectedMonsters.length; // Ataque cresce com combo

        if (selectedMonsters.every((e) => attackPower > e.health)) {
          _executeAttack();
          return;
        }
        currentQuestionIndex++;
      });

      Future.delayed(Duration(milliseconds: 300), () {
        _showNextQuestion();
      });
    } else {
      Future.delayed(Duration(milliseconds: 300), () {
        _executeAttack();
      });
    }
  }

  // void _showAnswerFeedback(bool isCorrect, int correctAnswer) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         isCorrect
  //             ? '✅ Correto! +${20 + (correctAnswers * 5)} poder'
  //             : '❌ Errado! A resposta era $correctAnswer',
  //       ),
  //       backgroundColor: isCorrect ? Colors.green : Colors.red,
  //       duration: Duration(seconds: 1),
  //     ),
  //   );
  // }

  void _executeAttack() {
    questionTimer?.cancel();

    setState(() {
      currentPhase = GamePhase.attackExecution;
    });

    _attackAnimation.forward();

    Future.delayed(Duration(milliseconds: 400), () {
      setState(() {
        // Aplicar dano aos monstros selecionados
        for (Monster monster in selectedMonsters) {
          monster.health -= attackPower;
          if (monster.health <= 0) {
            score += monster.points;
          }
        }

        // Remover monstros mortos
        selectedMonsters.removeWhere((monster) => monster.health <= 0);
        allMonsters.removeWhere((monster) => monster.health <= 0);
      });

      Future.delayed(Duration(milliseconds: 400), () {
        _attackAnimation.reset();

        if (allMonsters.isEmpty) {
          _nextRound();
        } else {
          _monstersAttack();
        }
      });
    });
  }

  void _monstersAttack() {
    setState(() {
      currentPhase = GamePhase.monsterAttack;
    });

    int totalDamage = 0;
    for (Monster monster in allMonsters) {
      totalDamage += monster.damage;
    }

    final storeDamage = totalDamage;

    if (armorPoints > 0) {
      totalDamage -= (totalDamage / 100 * (armorPoints * (round / 10))).toInt();
    }

    setState(() {
      if (totalDamage < 0) {
        totalDamage = (storeDamage * 0.01).toInt();
      }
      playerHealth -= totalDamage;
    });

    _damageAnimation.forward().then((_) => _damageAnimation.reset());

    if (playerHealth <= 0) {
      _gameOver();
    } else {
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          currentPhase = GamePhase.monsterSelection;
          selectedMonsters.clear();
        });
      });
    }
  }

  void _nextRound() {
    setState(() {
      round++;
      currentPhase = GamePhase.roundComplete;
    });

    Future.delayed(Duration(seconds: 2), () {
      _startNewRound();
    });
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
    });
    _saveScore();
  }

  void _saveScore() async {
    try {
      final docsToFind = (await FirebaseFirestore.instance
              .collection('rankings')
              .get())
          .docs
          .where((e) => e.id.contains(widget.playerName));

      for (final item in docsToFind) {
        final current = item.data();
        if (current['code'] == widget.playerCode) {
          if (current['score'] < score) {
            final doc = FirebaseFirestore.instance
                .collection('rankings')
                .doc(item.id);

            await doc.set({
              'score': score,
              'history': current['history']..add(score),
              'round': round,
            }, SetOptions(merge: true));
          }

          return;
        }
      }

      final docs = (await FirebaseFirestore.instance
              .collection('rankings')
              .get())
          .docs
          .map((e) {
            return e.id;
          });

      int count = 0;

      while (true) {
        if (!docs.contains(
          "${widget.playerName}#${count.toString().padLeft(4, '0')}",
        )) {
          await FirebaseFirestore.instance
              .collection('rankings')
              .doc('${widget.playerName}#${count.toString().padLeft(4, '0')}')
              .set({
                'playerName':
                    '${widget.playerName}#${count.toString().padLeft(4, '0')}',
                'code': widget.playerCode,
                'score': score,
                'history': [score],
                'round': round,
                'timestamp': FieldValue.serverTimestamp(),
              });
          return;
        }

        count++;
      }
    } catch (e) {
      print('Erro ao salvar pontuação: $e');
    }
  }

  Widget _buildHealthBar() {
    double healthPercent = playerHealth / maxHealth;
    Color healthColor =
        healthPercent > 0.6
            ? Colors.green
            : healthPercent > 0.3
            ? Colors.orange
            : Colors.red;

    return AnimatedBuilder(
      animation: _damageAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_damageAnimation.value * 0.1),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: healthPercent,

                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: healthColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerRight,
                        child:
                            healthPercent > 0.3
                                ? Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    '$playerHealth / $maxHealth',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                    ),
                    if (healthPercent < 0.3)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            '$playerHealth / $maxHealth',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: healthColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                '🪵 PAUS $armorPoints/100',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonsterSelectionPhase() {
    final limit = (7 - (round - (round % 10)) / 10).clamp(2, 999).toInt();

    return Expanded(
      child: Column(
        children: [
          Text(
            isBossRound
                ? '👹 ESCOLHA O BOSS PARA ENFRENTAR!'
                : '👾 ESCOLHA OS MONSTROS PARA ATACAR',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Selecionados: ${selectedMonsters.length} / $limit',
            style: TextStyle(fontSize: 16, color: Colors.yellowAccent),
          ),
          SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: allMonsters.length,
              itemBuilder: (context, index) {
                Monster monster = allMonsters[index];
                bool isSelected = selectedMonsters.contains(monster);

                return GestureDetector(
                  onTap: () => _selectMonster(monster),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.deepPurple
                              : (monster.isBoss
                                  ? Colors.red[700]
                                  : Colors.green[700]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.deepOrange : Colors.white,
                        width: isSelected ? 3 : 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(monster.icon, style: TextStyle(fontSize: 24)),
                        Text(
                          '${monster.name} (${monster.operation.symbol})',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'HP: ${monster.health}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'ATK: ${monster.damage}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'PTS: ${monster.points}',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (selectedMonsters.isNotEmpty)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startBattle,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'INICIAR BATALHA!',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onStore,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.white,
                ),
                child: Icon(Icons.shopping_cart, size: 24, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void onStore() async {
    await showDialog(
      context: context,

      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: EdgeInsets.all(10),
          title: Text('🛒 LOGINHA'),
          content: StoreContentWidget(),
          actions: [
            TextButton(
              child: Text('Fechar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    setState(() {});

    if (allMonsters.isEmpty) {
      _nextRound();
    }
  }

  Widget _buildBattleQuestionsPhase() {
    if (currentQuestionIndex >= battleQuestions.length) return Container();

    MathProblem currentProblem = battleQuestions[currentQuestionIndex];

    return Column(
      children: [
        Text(
          'PERGUNTA ${currentQuestionIndex + 1}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: timeLeft > 5 ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$timeLeft',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Poder de Ataque: $attackPower',
          style: TextStyle(
            fontSize: 16,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                currentProblem.problem,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ...currentProblem.options.asMap().entries.map((entry) {
                int index = entry.key;
                int option = entry.value;

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(vertical: 5),
                  child: ElevatedButton(
                    onPressed: () => _answerQuestion(index),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      backgroundColor:
                          displayCorrectButton
                              ? entry.key ==
                                      battleQuestions[currentQuestionIndex]
                                          .correctOption
                                  ? Colors.green
                                  : Colors.red
                              : Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('$option', style: TextStyle(fontSize: 18)),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttackExecutionPhase() {
    return AnimatedBuilder(
      animation: _attackAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Transform.scale(
              scale: 1.0 + (_attackAnimation.value * 0.3),
              child: Text(
                '⚡ ATACANDO! ⚡',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Poder do Ataque: $attackPower',
              style: TextStyle(
                fontSize: 24,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Acertos em Sequência: $correctAnswers',
              style: TextStyle(
                fontSize: 18,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[900]!, Colors.red[400]!],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GAME OVER!',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Pontuação Final: $score',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                Text(
                  'Rounds Sobrevividos: $round',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('VOLTAR AO MENU'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

            colors:
                isBossRound
                    ? [Colors.purple[900]!, Colors.red[700]!]
                    : [Colors.blue[900]!, Colors.blue[400]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Header com informações
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.playerName,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pontos: $score',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Round: $round',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                // Barra de vida
                AnimatedBuilder(
                  animation: _healAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_healAnimation.value * 0.1),
                      child: _buildHealthBar(),
                    );
                  },
                ),
                SizedBox(height: 20),

                // Fases do jogo
                Expanded(
                  child: Column(
                    children: [
                      if (currentPhase == GamePhase.monsterSelection)
                        _buildMonsterSelectionPhase(),

                      if (currentPhase == GamePhase.battleQuestions)
                        _buildBattleQuestionsPhase(),

                      if (currentPhase == GamePhase.attackExecution)
                        _buildAttackExecutionPhase(),

                      if (currentPhase == GamePhase.monsterAttack)
                        Column(
                          children: [
                            Text(
                              '👾 MONSTROS ATACANDO! 👾',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),

                      if (currentPhase == GamePhase.roundComplete)
                        Column(
                          children: [
                            Text(
                              '🎉 ROUND COMPLETO! 🎉',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Próximo round em breve...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreContentWidget extends StatefulWidget {
  const StoreContentWidget({super.key});

  @override
  State<StoreContentWidget> createState() => _StoreContentWidgetState();
}

class StoreItem {
  final int value;
  final String name;
  final String description;
  final VoidCallback callback;

  StoreItem({
    required this.value,
    required this.name,
    required this.description,
    required this.callback,
  });
}

class _StoreContentWidgetState extends State<StoreContentWidget> {
  List<StoreItem> options = [
    StoreItem(
      value: 50,
      name: '🐄 Cura de Leite',
      description: 'Esse leite cura',
      callback: () {
        playerHealth = (playerHealth + 50 + (round * 5)).clamp(1, maxHealth);
      },
    ),
    StoreItem(
      value: 70,
      name: '🪵 Peitoral de tora',
      description: 'Aumenta sua defesa para uma tora',
      callback: () {
        armorPoints += 1;
      },
    ),
    StoreItem(
      value: 100,
      name: '🎂 Bolo de fubá',
      description: 'Mais calorias pra vida',
      callback: () {
        maxHealth += 20;
      },
    ),
    StoreItem(
      value: 300,
      name: '☄️ Meteoro da paixão',
      description: 'Traga a paixão para todos',
      callback: () {
        allMonsters.removeWhere((monster) => !monster.isBoss);
      },
    ),
  ];

  ColorFilter get greyscale => const ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  _buildOptions() {
    return options
        .map(
          (e) => InkWell(
            onTap: () {
              e.callback.call();
              score -= e.value;
              OverlayEntry overlayEntry;
              overlayEntry = OverlayEntry(
                builder:
                    (context) => Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Material(
                        child: Container(
                          padding: EdgeInsets.all(10),
                          color: Colors.green,
                          child: Center(
                            child: Text(
                              '${e.name} adquirido com sucesso!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              );
              Overlay.of(context).insert(overlayEntry);
              Timer(const Duration(seconds: 1), () {
                overlayEntry.remove();
              });

              setState(() {});
              // Navigator.of(context).pop();
            },
            child: ColorFiltered(
              colorFilter:
                  score >= e.value
                      ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.plus,
                      )
                      : greyscale,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.deepPurple,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      e.description,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(5),
                        ),
                      ),
                      child: Text(
                        "PTS ${e.value.toString()}",
                        style: TextStyle(
                          color:
                              score >= e.value
                                  ? Colors.black
                                  : const Color.fromARGB(255, 211, 124, 119),
                          // fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Você tem $score pontos para gastar!'),
        SizedBox(height: 20),
        Expanded(child: ListView(children: _buildOptions())),
      ],
    );
  }
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🏆 RANKING'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple[900]!, Colors.deepPurple[400]!],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('rankings')
                  .orderBy('score', descending: true)
                  .limit(10)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erro ao carregar ranking',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> docs = snapshot.data!.docs;

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          actions: [
                            TextButton(
                              child: Text('Fechar'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                          insetPadding: EdgeInsets.all(10),
                          title: Text('👑 ${data['playerName']}'),
                          content: SizedBox(
                            width: 400,
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Maior Pontuação: ${data['score']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'HISTÓRICO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: ListView(
                                    children:
                                        (data['history'] ?? []).reversed
                                            .map<Widget>(
                                              (e) => Container(
                                                alignment: Alignment.center,
                                                margin: EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                padding: EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                        Radius.circular(10),
                                                      ),
                                                ),
                                                child: Text(
                                                  e.toString(),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },

                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          index < 3
                              ? Border.all(
                                color:
                                    index == 0
                                        ? Colors.amber
                                        : index == 1
                                        ? Colors.grey[400]!
                                        : Colors.brown,
                                width: 3,
                              )
                              : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                index < 3
                                    ? (index == 0
                                        ? Colors.amber
                                        : index == 1
                                        ? Colors.grey[400]!
                                        : Colors.brown)
                                    : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['playerName'] ?? 'Jogador',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Round: ${data['round'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${data['score'] ?? 0} pts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum Operation {
  plus("+"),
  minus("-"),
  multiply("*"),
  divide("÷");
  // power("^");

  final String symbol;
  const Operation(this.symbol);
}

Map<int, (String, Operation)> monsterMap = {
  50: ('Zumbi', Operation.plus),
  30: ('Corvo', Operation.minus),
  25: ('Esqueto', Operation.multiply),
  15: ('Ogro', Operation.divide),
  10: ('Demônio', Operation.multiply),
  5: ('Dragão', Operation.multiply),
};

class Monster {
  String name;
  String icon;
  Operation operation;
  int health;
  int damage;
  int points;
  bool isBoss;

  Monster({
    required this.name,
    required this.operation,
    required this.icon,
    required this.health,
    required this.damage,
    required this.points,
    this.isBoss = false,
  });

  static List<Monster> normal(int round, int elements) {
    // +
    // -
    // *
    // ÷
    // raiz
    // ^
    List<String> icons = ['🧟‍♂️', '🐦‍⬛', '💀', '🧌', '😈', '🐉'];
    final rand = Random();
    List<Monster> monsters = [];
    for (int i = 0; i < elements; i++) {
      final key = monsterMap.keys.firstWhere((k) {
        if (round * 10 > 100) {
          return k <= 5;
        }
        return k <= rand.nextInt(100 - round * 3).clamp(6, 100);
      });
      final data = monsterMap[key]!;

      final index = monsterMap.keys.toList().indexOf(key);

      int baseHealth = 50 + rand.nextInt(round * 5) + (index * 10);
      int baseDamage = rand.nextInt(round * 2) + (round * 2);
      int basePoints = 10 + rand.nextInt(round * 5) + (index * 10);

      monsters.add(
        Monster(
          name: data.$1,
          operation: data.$2,
          icon: icons[index],
          health: baseHealth,
          damage: baseDamage,
          points: basePoints,
        ),
      );
    }

    return monsters;
  }

  factory Monster.boss(int round) {
    // int bossHealth = 5;
    int bossHealth = 80 + (round * 15);
    int bossDamage = 10 + (round * 3);
    int bossPoints = 50 + (round * 10); // Corrigido: Completa a lógica
    return Monster(
      name: 'Boss Round $round',
      icon: '🐦‍🔥',
      operation: Operation.multiply,
      health: bossHealth,
      damage: bossDamage,
      points: bossPoints,
      isBoss: true,
    );
  }
}

class MathProblem {
  final String problem;
  final List<int> options;
  final int correctOption;
  final int answer;

  MathProblem({
    required this.problem,
    required this.options,
    required this.correctOption,
    required this.answer,
  });

  static MathProblem generate(int difficulty, List<Monster> monsters) {
    final Random random = Random();

    List<int> numbers = List.generate(
      monsters.length + 1,
      (i) => random.nextInt(9 * difficulty) + 1,
    );

    int result = 0;

    // monsters.shuffle();

    // for (int i = 0; i < monsters.length; i++) {
    //   switch (monsters[i].operation) {
    //     case Operation.plus:
    //       result += numbers[i];
    //       break;
    //     case Operation.minus:
    //       result -= numbers[i];
    //       break;
    //     case Operation.multiply:
    //       if (i == 0 && result == 0) {
    //         result += 1;
    //       }

    //       result *= numbers[i];
    //       break;
    //     case Operation.divide:
    //       if (numbers[i] == 0) {
    //         numbers[i] = 1;
    //       }

    //       numbers[i] ~/= numbers[i];
    //       break;
    //     case Operation.power:
    //       numbers[i] ^= numbers[i];
    //       break;
    //     // case Operation.sqrt:
    //     //   int sqrtNumber = sqrt(numbers[i]).toInt();
    //     //   while (sqrtNumber * sqrtNumber != numbers[i]) {
    //     //     sqrtNumber--;
    //     //   }
    //     //   numbers[i] = sqrtNumber;
    //     //   break;
    //   }
    // }

    // int operation = random.nextInt(3); // 0: +, 1: -, 2: ×

    // String opSymbol = ['+', '-', 'X'][operation];

    // switch (operation) {
    //   case 0:
    //     for (final item in numbers) {
    //       result += item;
    //     }
    //     break;
    //   case 1:
    //     result = numbers[0];
    //     for (final item in numbers) {
    //       if (numbers.indexOf(item) == 0) continue;
    //       result -= item;
    //     }
    //     break;
    //   case 2:
    //     result += 1;

    //     final initial = numbers[0];
    //     numbers =
    //         numbers.sublist(1).map((e) {
    //           return (e ~/ 2).clamp(1, 900);
    //         }).toList();

    //     numbers.insert(0, initial);
    //     for (final item in numbers) {
    //       result *= item;
    //     }
    //     break;
    //   case 3:
    //     result = numbers.fold(0, (num1, num2) => num1 ~/ num2);
    //     break;
    //   default:
    //     result = 0;
    // }

    // Gerar opções de resposta com 3 alternativas erradas

    final problem =
        '${List.generate(monsters.length, (index) {
          return '${numbers[index]} ${monsters[index].operation.symbol}';
        }).join(' ')} ${numbers[monsters.length]}';

    result = eval(problem.replaceAll('÷', '~/'));

    List<int> options = [result];

    for (int i = 0; i < 3; i++) {
      int wrongAnswer;
      do {
        wrongAnswer = result + random.nextInt(40) - 2;
      } while (options.contains(wrongAnswer));

      options.add(wrongAnswer);
    }

    options.shuffle();

    return MathProblem(
      problem: problem,
      options: options,
      correctOption: options.indexOf(result),
      answer: result,
    );
  }
}

class KDebouncer {
  KDebouncer({this.milliseconds}) {
    milliseconds ??= 500;
  }

  int? milliseconds;
  VoidCallback? action;
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  run(VoidCallback action) {
    if (isRunning) {
      _timer?.cancel();
    }
    _timer = Timer(
      milliseconds != null
          ? Duration(milliseconds: milliseconds!)
          : Duration(milliseconds: 300),
      action,
    );
  }
}
