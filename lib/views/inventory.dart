import 'package:flutter/material.dart';
import 'inputs.dart';

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
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  bool _isDrawerOpen = false;

  final List<String> _categories = [
    'Todas las categorías',
    'Eléctricas',
    'Medición',
    'Herramientas manuales',
    'Equipos de seguridad',
  ];

  final List<String> _locations = [
    'Todas las ubicaciones',
    'Taller A',
    'Laboratorio',
    'Almacén 1',
    'Almacén 2',
  ];

  final List<Map<String, dynamic>> _inventory = [
    {
      'id': 'HT-0024',
      'name': 'Taladro Makita',
      'category': 'Eléctricas',
      'location': 'Taller A',
      'price': 1250,
      'available': 3,
      'status': 'available',
    },
    {
      'id': 'HT-0089',
      'name': 'Calibrador Digital',
      'category': 'Medición',
      'location': 'Laboratorio',
      'price': 3500,
      'available': 0,
      'status': 'damaged',
      'damaged': 1,
    },
    {
      'id': 'HT-0156',
      'name': 'Martillo de Acero',
      'category': 'Herramientas manuales',
      'location': 'Taller A',
      'price': 450,
      'available': 5,
      'status': 'available',
    },
    {
      'id': 'HT-0234',
      'name': 'Multímetro Digital',
      'category': 'Eléctricas',
      'location': 'Laboratorio',
      'price': 850,
      'available': 2,
      'status': 'available',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7, // Más pequeña 
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 300.0, // Más desplazamiento hacia la derecha
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: -0.3, // Más rotación para mayor perspectiva
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    // Debug
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
    // Debug
    if (_isDrawerOpen) {
      _animationController.reverse();
      setState(() {
        _isDrawerOpen = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredInventory {
    return _inventory.where((item) {
      final matchesSearch = item['name']
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todas las categorías' ||
          item['category'] == _selectedCategory;
      final matchesLocation = _selectedLocation == 'Todas las ubicaciones' ||
          item['location'] == _selectedLocation;

      return matchesSearch && matchesCategory && matchesLocation;
    }).toList();
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle del modal
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header del modal
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtros',
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
              
              // Contenido de filtros
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filtro de categorías
                      const Text(
                        'Categorías',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCategory = newValue!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Filtro de ubicaciones
                      const Text(
                        'Ubicaciones',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedLocation,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _locations.map((String location) {
                            return DropdownMenuItem<String>(
                              value: location,
                              child: Text(location),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLocation = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Botones de acción
              Container(
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                          setState(() {}); // Actualiza la vista con los filtros
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 5, 45, 77),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Aplicar filtros',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
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
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              // Sidebar (Drawer)
              _buildSidebar(),
              
              // Main Content con transformación 3D
              Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0008) // Más perspectiva
                  ..translate(_slideAnimation.value)
                  ..scale(_scaleAnimation.value)
                  ..rotateY(_rotationAnimation.value),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_isDrawerOpen ? 25 : 0),
                    boxShadow: _isDrawerOpen
                        ? [
                            BoxShadow(
                              // ignore: deprecated_member_use
                              color: Colors.black.withOpacity(0.4),
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
              ),
              
              // Overlay cuando el drawer está abierto
              if (_isDrawerOpen)
                Positioned(
                  left: 320, // Ajustado para el nuevo desplazamiento
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Debug
                      _closeDrawer();
                    },
                    child: Container(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.05), // Más sutil
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: Column(
          children: [
            // Header del sidebar con perfil de usuario
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 60,
                bottom: 30,
              ),
              child: Column(
                children: [
                  // Avatar del usuario
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      border: Border.all(
                        color: Colors.grey[700]!,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nombre del usuario
                  const Text(
                    'Ezequiel Velez',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Cargo
                  Text(
                    'Administrador de Inventario',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildMenuTile(
                    icon: Icons.dashboard,
                    title: 'Inicio',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop(); // Regresa al dashboard
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.inventory,
                    title: 'Inventario',
                    isActive: true,
                    onTap: () {
                      _closeDrawer();
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.arrow_downward,
                    title: 'Entradas',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const InputsScreen(),
                          ),
                        );
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.assignment,
                    title: 'Asignaciones',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Asignaciones - Próximamente')),
                        );
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.arrow_upward,
                    title: 'Devoluciones',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Devoluciones - Próximamente')),
                        );
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.refresh,
                    title: 'Reposiciones',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reposiciones - Próximamente')),
                        );
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.bar_chart,
                    title: 'Reportes',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reportes - Próximamente')),
                        );
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.admin_panel_settings,
                    title: 'Administración',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Administración - Próximamente')),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Botón de cerrar sesión
            Container(
              padding: const EdgeInsets.all(20),
              child: _buildMenuTile(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                isLogout: true,
                onTap: () {
                  _closeDrawer();
                  Future.delayed(const Duration(milliseconds: 350), () {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          icon: const Icon(
            Icons.menu,
            color: Colors.black,
          ),
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
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
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
                                content: Text('Función de escáner QR próximamente'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 6, 55, 112),
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
                            side: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
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
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredInventory.length,
                itemBuilder: (context, index) {
                  final item = filteredInventory[index];
                  return _buildInventoryCard(item);
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['category']} • ${item['location']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
                    '\$${item['price'].toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
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
                          SnackBar(
                            content: Text('Prestar ${item['name']}'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 18, 87, 197), // Verde más atractivo
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
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

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    bool isActive = false,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Debug print
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive 
                  // ignore: deprecated_member_use
                  ? Colors.red.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  // ignore: deprecated_member_use
                  ? Border.all(color: Colors.red.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isLogout 
                      ? Colors.red 
                      : isActive 
                          ? Colors.red 
                          : Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isLogout 
                        ? Colors.red 
                        : isActive 
                            ? Colors.white 
                            : Colors.grey[300],
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
