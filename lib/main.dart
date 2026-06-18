import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageManager.loadFromStorage();
  runApp(const MyApp());
}

class HistoryEntry {
  final String id;
  final String type;
  final double amount;
  final double cost;
  final double profit;
  final String description;
  final double unitCostAtTime;
  final double unitPriceAtTime;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.cost,
    required this.profit,
    required this.description,
    required this.unitCostAtTime,
    required this.unitPriceAtTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'cost': cost,
        'profit': profit,
        'description': description,
        'unitCostAtTime': unitCostAtTime,
        'unitPriceAtTime': unitPriceAtTime,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] ?? '',
        type: json['type'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        cost: (json['cost'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
        description: json['description'] ?? '',
        unitCostAtTime: (json['unitCostAtTime'] as num).toDouble(),
        unitPriceAtTime: (json['unitPriceAtTime'] as num).toDouble(),
      );
}

class OperatorData extends ChangeNotifier {
  double _stock = 0;
  double _costValue = 0;
  double _profit = 0;
  double _totalSoldValue = 0;
  double _totalCapitalRecovered = 0;
  final List<HistoryEntry> _history = [];

  double get stock => _stock;
  double get costValue => _costValue;
  double get profit => _profit;
  double get totalSoldValue => _totalSoldValue;
  double get totalCapitalRecovered => _totalCapitalRecovered;
  List<HistoryEntry> get history => List.unmodifiable(_history);

  double get currentUnitCost => _stock > 0 ? (_costValue / _stock) : 0;
  double get investedCapitalInStock => _costValue;
  double get totalCashFlow => _profit + _totalCapitalRecovered;

  Map<String, dynamic> toJson() => {
        'stock': _stock,
        'costValue': _costValue,
        'profit': _profit,
        'totalSoldValue': _totalSoldValue,
        'totalCapitalRecovered': _totalCapitalRecovered,
        'history': _history.map((h) => h.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _stock = (json['stock'] as num?)?.toDouble() ?? 0;
    _costValue = (json['costValue'] as num?)?.toDouble() ?? 0;
    _profit = (json['profit'] as num?)?.toDouble() ?? 0;
    _totalSoldValue = (json['totalSoldValue'] as num?)?.toDouble() ?? 0;
    _totalCapitalRecovered = (json['totalCapitalRecovered'] as num?)?.toDouble() ?? 0;
    _history.clear();
    if (json['history'] != null) {
      for (var h in (json['history'] as List)) {
        _history.add(HistoryEntry.fromJson(h));
      }
    }
    notifyListeners();
  }

  void addAchat(double m, double p) {
    if (m <= 0 || p < 0) return;
    _stock += m;
    _costValue += p;
    _history.add(
      HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: "ACHAT",
        amount: m,
        cost: p,
        profit: 0,
        description:
            "Achat: ${m.toStringAsFixed(2)} | Total: ${p.toStringAsFixed(2)} DT",
        unitCostAtTime: p / m,
        unitPriceAtTime: p / m,
      ),
    );
    notifyListeners();
    unawaited(StorageManager.saveToStorage());
  }

  void addVente(double val, double pv) {
    if (val <= 0 || _stock <= 0 || val > _stock) return;
    double pu = currentUnitCost;
    double coutReel = val * pu;
    double benef = pv - coutReel;
    double unitPrice = pv / val;

    _stock -= val;
    _costValue -= coutReel;
    _profit += benef;
    _totalSoldValue += val;
    _totalCapitalRecovered += coutReel;

    _history.add(
      HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: "VENTE",
        amount: val,
        cost: coutReel,
        profit: benef,
        description:
            "Vente: ${val.toStringAsFixed(2)} | Profit: ${benef.toStringAsFixed(2)} DT | P.U: ${unitPrice.toStringAsFixed(3)}",
        unitCostAtTime: pu,
        unitPriceAtTime: unitPrice,
      ),
    );
    notifyListeners();
    unawaited(StorageManager.saveToStorage());
  }

  void removeHistory(HistoryEntry entry) {
    if (entry.type == "ACHAT") {
      _stock -= entry.amount;
      _costValue -= entry.cost;
    } else {
      _stock += entry.amount;
      _costValue += entry.cost;
      _profit -= entry.profit;
      _totalSoldValue -= entry.amount;
      _totalCapitalRecovered -= entry.cost;
    }
    _history.removeWhere((h) => h.id == entry.id);
    notifyListeners();
    unawaited(StorageManager.saveToStorage());
  }
}

// Memory Save/Load Manager mapping global structures to exportable string packages
class StorageManager {
  static const String _storageKey = 'gestion_solde_backup';

  static String exportToPackageString() {
    final Map<String, dynamic> rootMap = {
      "operators": operators.map((k, v) => MapEntry(k, v.toJson())),
      "cti": ctiData.map((k, v) => MapEntry(k, v.toJson())),
      "dollar": dollarData.map((k, v) => MapEntry(k, v.toJson())),
      "euro": euroData.map((k, v) => MapEntry(k, v.toJson())),
    };
    return jsonEncode(rootMap);
  }

  static Future<void> saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, exportToPackageString());
  }

  static Future<bool> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson == null || rawJson.isEmpty) return false;
      return importFromPackageString(rawJson);
    } catch (e) {
      debugPrint('Loading backup failure: $e');
      return false;
    }
  }

  static bool importFromPackageString(String rawJson) {
    try {
      if (rawJson.isEmpty) return false;
      final Map<String, dynamic> rootMap = jsonDecode(rawJson);

      if (rootMap["operators"] != null) {
        (rootMap["operators"] as Map).forEach((k, v) {
          if (operators.containsKey(k)) operators[k]!.loadFromJson(v);
        });
      }
      if (rootMap["cti"] != null) {
        (rootMap["cti"] as Map).forEach((k, v) {
          if (ctiData.containsKey(k)) ctiData[k]!.loadFromJson(v);
        });
      }
      if (rootMap["dollar"] != null) {
        (rootMap["dollar"] as Map).forEach((k, v) {
          if (dollarData.containsKey(k)) dollarData[k]!.loadFromJson(v);
        });
      }
      if (rootMap["euro"] != null) {
        (rootMap["euro"] as Map).forEach((k, v) {
          if (euroData.containsKey(k)) euroData[k]!.loadFromJson(v);
        });
      }
      return true;
    } catch (e) {
      debugPrint("Parsing backup failure: $e");
      return false;
    }
  }
}

final Map<String, OperatorData> operators = {
  "Ooredoo": OperatorData(),
  "Orange": OperatorData(),
  "Tunisie Telecom": OperatorData(),
};

final Map<String, Color> operatorColors = {
  "Ooredoo": Colors.redAccent,
  "Orange": Colors.orangeAccent,
  "Tunisie Telecom": Colors.blueAccent,
};

final Map<String, OperatorData> ctiData = {"CTI": OperatorData()};
final Map<String, OperatorData> dollarData = {"Dollar": OperatorData()};
final Map<String, OperatorData> euroData = {"Euro": OperatorData()};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Helper method to display backup dialog boxes cleanly
  void _showBackupDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sauvegarde & Restauration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Générer Texte de Sauvegarde"),
              onPressed: () {
                final backupString = StorageManager.exportToPackageString();
                textController.text = backupString;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Collez votre texte de sauvegarde ici pour restaurer...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              final success = StorageManager.importFromPackageString(textController.text);
              if (success) {
                unawaited(StorageManager.saveToStorage());
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? "Données restaurées avec succès !" : "Erreur: Texte de sauvegarde invalide."),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text("Appliquer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Gestion Solde",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.sd_storage, color: Colors.indigo),
            tooltip: "Backup Data",
            onPressed: () => _showBackupDialog(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            _MenuButton(
              "Vente Solde & Internet",
              Icons.sim_card_outlined,
              Colors.indigo,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OperatorsPage()),
              ),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              "Vente Euro",
              Icons.euro_symbol,
              Colors.teal,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SpecializedPage("Euro", "Euro", Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              "Vente CTI",
              Icons.credit_card_outlined,
              Colors.deepPurple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SpecializedPage("CTI", "CTI", Colors.deepPurple),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              "Vente Dollar",
              Icons.attach_money_outlined,
              Colors.amber.shade800,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SpecializedPage("Dollar", "Dollar", Colors.amber),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _MenuButton(this.title, this.icon, this.color, this.onPressed);

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      );
}

class OperatorsPage extends StatelessWidget {
  const OperatorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Opérateurs")),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: operators.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final name = operators.keys.elementAt(i);
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: operatorColors[name],
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: operatorColors[name]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OperatorPage(name)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OperatorPage extends StatefulWidget {
  final String operatorName;
  const OperatorPage(this.operatorName, {super.key});

  @override
  State<OperatorPage> createState() => _OperatorPageState();
}

class _OperatorPageState extends State<OperatorPage> {
  final aM = TextEditingController(), aP = TextEditingController();
  final vV = TextEditingController(), vP = TextEditingController();

  @override
  void dispose() {
    aM.dispose();
    aP.dispose();
    vV.dispose();
    vP.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = operators[widget.operatorName]!;
    final color = operatorColors[widget.operatorName] ?? Colors.indigo;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.operatorName,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SummaryCard(data, color),
            const SizedBox(height: 24),
            _ActionSection(
              "Achat",
              Colors.amber.shade700,
              aM,
              aP,
              () {
                data.addAchat(
                  double.tryParse(aM.text) ?? 0,
                  double.tryParse(aP.text) ?? 0,
                );
                aM.clear();
                aP.clear();
              },
            ),
            const SizedBox(height: 12),
            _ActionSection(
              "Vente",
              Colors.green.shade600,
              vV,
              vP,
              () {
                data.addVente(
                  double.tryParse(vV.text) ?? 0,
                  double.tryParse(vP.text) ?? 0,
                );
                vV.clear();
                vP.clear();
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                "Historique Récent",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ...data.history.reversed.map<Widget>(
              (h) => _HistoryTile(h, data.removeHistory),
            ),
          ],
        ),
      ),
    );
  }
}

class SpecializedPage extends StatefulWidget {
  final String keyName;
  final String title;
  final Color themeColor;
  const SpecializedPage(this.keyName, this.title, this.themeColor, {super.key});

  @override
  State<SpecializedPage> createState() => _SpecializedPageState();
}

class _SpecializedPageState extends State<SpecializedPage> {
  late OperatorData data;
  final aE = TextEditingController(),
      aP = TextEditingController(),
      vE = TextEditingController(),
      vP = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.keyName == "CTI") {
      data = ctiData["CTI"]!;
    } else if (widget.keyName == "Dollar") {
      data = dollarData["Dollar"]!;
    } else {
      data = euroData["Euro"]!;
    }
  }

  @override
  void dispose() {
    aE.dispose();
    aP.dispose();
    vE.dispose();
    vP.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            "Gestion ${widget.title}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SummaryCard(data, widget.themeColor),
            const SizedBox(height: 24),
            _ActionSection(
              "Achat ${widget.title}",
              Colors.amber.shade700,
              aE,
              aP,
              () {
                data.addAchat(
                  double.tryParse(aE.text) ?? 0,
                  double.tryParse(aP.text) ?? 0,
                );
                aE.clear();
                aP.clear();
              },
            ),
            const SizedBox(height: 12),
            _ActionSection(
              "Vente ${widget.title}",
              Colors.green.shade600,
              vE,
              vP,
              () {
                data.addVente(
                  double.tryParse(vE.text) ?? 0,
                  double.tryParse(vP.text) ?? 0,
                );
                vE.clear();
                vP.clear();
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                "Historique",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ...data.history.reversed.map<Widget>(
              (h) => _HistoryTile(h, data.removeHistory),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry h;
  final Function(HistoryEntry) onDelete;
  const _HistoryTile(this.h, this.onDelete);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(h.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(h),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            h.type == "ACHAT"
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            color: h.type == "ACHAT"
                ? Colors.amber.shade700
                : Colors.green.shade600,
          ),
          title: Text(
            h.description,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: h.type == "VENTE"
              ? Text(
                  "Coût réel: ${h.cost.toStringAsFixed(2)} DT",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              : null,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final OperatorData d;
  final Color color;
  const _SummaryCard(this.d, this.color);
  @override
  Widget build(BuildContext context) => Card(
        color: color.withAlpha(20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                "Capital Récupérable",
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${d.totalCapitalRecovered.toStringAsFixed(2)} DT",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 32),
              Text(
                "Bilan Total",
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                "${d.totalCashFlow.toStringAsFixed(2)} DT",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoCol("Profit", "${d.profit.toStringAsFixed(2)} DT"),
                  _infoCol("Stock", d.stock.toStringAsFixed(2)),
                  _infoCol("Unité", d.currentUnitCost.toStringAsFixed(2)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _infoCol(String label, String val) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      );
}

class _ActionSection extends StatelessWidget {
  final String title;
  final Color color;
  final TextEditingController c1, c2;
  final VoidCallback onValid;
  const _ActionSection(this.title, this.color, this.c1, this.c2, this.onValid);
  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withAlpha(100)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withAlpha(50)),
          ),
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: c1,
                    decoration: InputDecoration(
                      labelText: "Quantité",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c2,
                    decoration: InputDecoration(
                      labelText: "Prix Total (DT)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onValid,
                      child: const Text(
                        "Valider",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
