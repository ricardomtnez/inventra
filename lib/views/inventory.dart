import 'package:flutter/material.dart';
import '../components/custom_sidebar.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Quaternion;
import '../api/inventary_controller.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Todas las categorías';
  String _selectedLocation = 'Todas las ubicaciones';
  late Future<List<String>> _categoriesFuture;
  final InventaryController _controller = InventaryController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  bool _isDrawerOpen = false;

  final List<String> _locations = [
    'Todas las ubicaciones',
    'Taller A',
    'Laboratorio',
    'Almacén 1',
    'Almacén 2',
  ];

  List<Map<String, dynamic>> _inventory = [];
  late Future<List<Map<String, dynamic>>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _controller.obtenerCategorias();
    _inventoryFuture = _controller.obtenerInventarioHerramienta();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 300.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: -0.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    if (_isDrawerOpen) {
      _animationController.reverse();
      setState(() {
        _isDrawerOpen = false;
      });
    } else {
      _animationController.forward();
      setState(() {
        _isDrawerOpen = true;
      });
    }
  }

  void _closeDrawer() {
    if (_isDrawerOpen) {
      _animationController.reverse();
      setState(() {
        _isDrawerOpen = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredInventory {
    return _inventory.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(
        _searchController.text.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == 'Todas las categorías' ||
          item['category'] == _selectedCategory;
      final matchesLocation =
          _selectedLocation == 'Todas las ubicaciones' ||
          item['location'] == _selectedLocation;

      return matchesSearch && matchesCategory && matchesLocation;
    }).toList();
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Barra superior
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Filtros",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FutureBuilder<List<String>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text("No se encontraron categorías");
                      }

                      List<String> categorias =
                          snapshot.data!; // Ya incluye "Todas las categorías"

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Categorías",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: categorias.contains(_selectedCategory)
                                ? _selectedCategory
                                : categorias.first,
                            items: categorias.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategory = value!);
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            "Ubicaciones",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Dropdown ubicaciones
                          DropdownButtonFormField<String>(
                            value: _selectedLocation,
                            items: _locations.map((loc) {
                              return DropdownMenuItem(
                                value: loc,
                                child: Text(loc),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedLocation = value!);
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Botones inferiores
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = 'Todas las categorías';
                            _selectedLocation = 'Todas las ubicaciones';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Limpiar filtros',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 5, 45, 77),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Aplicar filtros',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          // Sidebar
          CustomSidebar(),

          // Main Content con animación
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.compose(
                  Vector3(_slideAnimation.value, 0.0, 0.0),
                  Quaternion.axisAngle(
                    Vector3(0, 1, 0),
                    _rotationAnimation.value,
                  ),
                  Vector3.all(_scaleAnimation.value),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_isDrawerOpen ? 25 : 0),
                    boxShadow: _isDrawerOpen
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 8,
                              offset: const Offset(-5, 0),
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_isDrawerOpen ? 25 : 0),
                    child: _buildMainContent(),
                  ),
                ),
              );
            },
          ),

          // Overlay cuando el drawer está abierto
          if (_isDrawerOpen)
            Positioned(
              left: 300,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _closeDrawer,
                child: Container(color: Colors.black.withValues(alpha: 0.05)),
              ),
            ),
        ],
      ),
    );
  }

  // El resto de tus métodos (_buildMainContent, _buildInventoryCard, _getStatusColor, _getStatusText) permanecen igual

  Widget _buildMainContent() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _toggleDrawer,
          icon: const Icon(Icons.menu, color: Colors.black),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Inventario',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'Lista de herramientas y equipos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey[300], height: 1.0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            // Sección de filtros
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  // Barra de búsqueda
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar herramienta...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fila de botones
                  Row(
                    children: [
                      // Botón Escanear QR
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Función de escáner QR próximamente',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              6,
                              55,
                              112,
                            ),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: const Text(
                            'Escanear QR',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botón Filtrar
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showFilterModal(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.tune, size: 20),
                          label: const Text(
                            'Filtrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lista de inventario
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _inventoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No hay datos"));
                  }

                  _inventory =
                      snapshot.data!; // Guardamos datos en la lista principal

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredInventory.length,
                    itemBuilder: (context, index) {
                      final item = filteredInventory[index];
                      return _buildInventoryCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Contenido principal
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: solo la imagen
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen/código del producto
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A5568),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        item['id'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Información del producto debajo de la imagen
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['id']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['category']} • ${item['location']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Fila inferior: precio a la izquierda, botón a la derecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '\$${item['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  // Botón de acción
                  if (item['status'] == 'available')
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Prestar ${item['name']}')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          18,
                          87,
                          197,
                        ), // Verde más atractivo
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Prestar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sin stock',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Indicador de estado en la esquina superior derecha
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: _getStatusColor(item['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(item['status']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(item),
                    style: TextStyle(
                      color: _getStatusColor(item['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.orange;
      case 'damaged':
        return Colors.red;
      case 'maintenance':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(Map<String, dynamic> item) {
    if (item['status'] == 'available') {
      return '${item['available']} disponibles';
    } else if (item['status'] == 'damaged') {
      return '${item['damaged']} dañadas';
    } else {
      return 'Mantenimiento';
    }
  }
}
