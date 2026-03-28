import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CropYieldApp());
}

class CropYieldApp extends StatelessWidget {
  const CropYieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rwanda Crop Yield Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
static const String apiUrl = 'https://rwanda-crop-yield.onrender.com/predict';
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _yearCtrl         = TextEditingController();
  final _areaCtrl         = TextEditingController();
  final _productionCtrl   = TextEditingController();
  final _lag1Ctrl         = TextEditingController();
  final _lag2Ctrl         = TextEditingController();
  final _rolling3Ctrl     = TextEditingController();

  String? _selectedCrop;
  String  _resultText     = '';
  bool    _isLoading      = false;
  bool    _hasError       = false;

  final List<String> _crops = [
    'Avocados', 'Bananas', 'Barley', 'Cabbages', 'Carrots and turnips',
    'Chillies and peppers, green (Capsicum spp. and Pimenta spp.)',
    'Coffee, green', 'Eggplants (aubergines)', 'Groundnuts, excluding shelled',
    'Leeks and other alliaceous vegetables', 'Lemons and limes',
    'Mangoes, guavas and mangosteens', 'Millet',
    'Onions and shallots, dry (excluding dehydrated)', 'Oranges',
    'Other beans, green', 'Other fruits, n.e.c.',
    'Other stimulant, spice and aromatic crops, n.e.c.',
    'Other tropical fruits, n.e.c.', 'Other vegetables, fresh n.e.c.',
    'Papayas', 'Peas, dry', 'Pepper (Piper spp.), raw', 'Pineapples',
    'Pumpkins, squash and gourds', 'Pyrethrum, dried flowers', 'Rice',
    'Seed cotton, unginned', 'Soya beans', 'Sugar cane', 'Taro', 'Tomatoes',
    'Unmanufactured tobacco', 'Wheat', 'Yams',
  ];

  @override
  void dispose() {
    _yearCtrl.dispose();
    _areaCtrl.dispose();
    _productionCtrl.dispose();
    _lag1Ctrl.dispose();
    _lag2Ctrl.dispose();
    _rolling3Ctrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      setState(() {
        _hasError  = true;
        _resultText = 'Please select a crop type.';
      });
      return;
    }

    setState(() { _isLoading = true; _resultText = ''; _hasError = false; });

    try {
      final body = jsonEncode({
        'year':           int.parse(_yearCtrl.text.trim()),
        'area_harvested': double.tryParse(_areaCtrl.text.trim()) ?? 0.0,
        'production':     double.tryParse(_productionCtrl.text.trim()) ?? 0.0,
        'yield_lag1':     double.tryParse(_lag1Ctrl.text.trim()) ?? 0.0,
        'yield_lag2':     double.tryParse(_lag2Ctrl.text.trim()) ?? 0.0,
        'yield_rolling3': double.tryParse(_rolling3Ctrl.text.trim()) ?? 0.0,
        'crop_name':      _selectedCrop,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 80));


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hasError   = false;
          _resultText =
              'Predicted Yield:\n'
              '${data['predicted_yield_hg_ha']} hg/ha\n'
              '(${data['predicted_yield_t_ha']} t/ha)\n\n'
              'Crop: ${data['crop']}\n'
              'Year: ${data['year']}';
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _hasError   = true;
          _resultText = 'Error: ${error['detail'] ?? 'Unexpected error occurred.'}';
        });
      }
    } on FormatException {
      setState(() {
        _hasError   = true;
        _resultText = 'Error: Please ensure all fields have valid numeric values.';
      });
    } catch (e) {
      setState(() {
        _hasError   = true;
        _resultText = 'Error: Could not connect to the API.\n$e';
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _clearAll() {
    _formKey.currentState?.reset();
    _yearCtrl.clear();
    _areaCtrl.clear();
    _productionCtrl.clear();
    _lag1Ctrl.clear();
    _lag2Ctrl.clear();
    _rolling3Ctrl.clear();
    setState(() {
      _selectedCrop = null;
      _resultText   = '';
      _hasError     = false;
    });
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    bool isInt = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isInt
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: isInt
            ? [FilteringTextInputFormatter.digitsOnly]
            : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Row(
          children: [
            Icon(Icons.grass, size: 22),
            SizedBox(width: 8),
            Text('Rwanda Crop Yield Predictor',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text(
                    'Enter farm details below to predict crop yield '
                    'in hectograms per hectare (hg/ha).',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),

                _sectionTitle('Basic Information'),
                const SizedBox(height: 10),

                _buildField(
                  controller: _yearCtrl,
                  label: 'Year',
                  hint: 'e.g. 2024',
                  isInt: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Year is required';
                    final y = int.tryParse(v);
                    if (y == null || y < 1961 || y > 2030) return 'Year must be between 1961 and 2030';
                    return null;
                  },
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCrop,
                    decoration: InputDecoration(
                      labelText: 'Crop Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    hint: const Text('Select a crop'),
                    isExpanded: true,
                    items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _selectedCrop = v),
                    validator: (v) => v == null ? 'Please select a crop' : null,
                  ),
                ),

                _sectionTitle('Farm Data'),
                const SizedBox(height: 10),

                _buildField(
                  controller: _areaCtrl,
                  label: 'Area Harvested (ha)',
                  hint: 'e.g. 15000',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0 || d > 5000000) return 'Must be between 0 and 5,000,000';
                    return null;
                  },
                ),

                _buildField(
                  controller: _productionCtrl,
                  label: 'Production (tonnes)',
                  hint: 'e.g. 180000',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0 || d > 50000000) return 'Must be between 0 and 50,000,000';
                    return null;
                  },
                ),

                _sectionTitle('Historical Yield (hg/ha)'),
                const SizedBox(height: 10),

                _buildField(
                  controller: _lag1Ctrl,
                  label: 'Previous Year Yield',
                  hint: 'e.g. 12000',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0 || d > 200000) return 'Must be between 0 and 200,000';
                    return null;
                  },
                ),

                _buildField(
                  controller: _lag2Ctrl,
                  label: 'Yield 2 Years Ago',
                  hint: 'e.g. 11500',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0 || d > 200000) return 'Must be between 0 and 200,000';
                    return null;
                  },
                ),

                _buildField(
                  controller: _rolling3Ctrl,
                  label: '3-Year Average Yield',
                  hint: 'e.g. 11800',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0 || d > 200000) return 'Must be between 0 and 200,000';
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: green),
                          foregroundColor: green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _predict,
                        icon: _isLoading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.agriculture),
                        label: Text(_isLoading ? 'Predicting...' : 'Predict',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (_resultText.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _hasError
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasError
                            ? Colors.red.shade300
                            : Colors.green.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _hasError ? Icons.error_outline : Icons.check_circle_outline,
                          color: _hasError ? Colors.red.shade700 : Colors.green.shade700,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _resultText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _hasError ? Colors.red.shade800 : Colors.green.shade800,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87,
        )),
      ],
    );
  }
}
