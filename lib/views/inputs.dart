import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class InputsScreen extends StatefulWidget {
  const InputsScreen({super.key});

  @override
  State<InputsScreen> createState() => _InputsScreenState();
}

class _InputsScreenState extends State<InputsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  bool _isDrawerOpen = false;

  // Controlador para el buscador
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Controladores de scroll
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Filtro por mes (1-12) - null = sin filtro
  int? _selectedMonth;
  // Año seleccionado para el filtro
  int? _selectedYear;
  final List<String> _monthNames = const [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  // Datos de ejemplo para el historial de entradas
  final List<Map<String, dynamic>> _entradas = [
    {
      'herramienta': 'Taladro Makita',
      'codigo': 'HT-0024',
      'cantidad': 5,
      'lugarResguardo': 'Almacén Central',
      'fecha': '10/11/2024',
    },
    {
      'herramienta': 'Casco de Seguridad',
      'codigo': 'HT-0078',
      'cantidad': 10,
      'lugarResguardo': 'Bodega 1',
      'fecha': '09/11/2024',
    },
    {
      'herramienta': 'Multímetro Digital',
      'codigo': 'HT-0234',
      'cantidad': 3,
      'lugarResguardo': 'Taller A',
      'fecha': '08/11/2024',
    },
    {
      'herramienta': 'Martillo de Acero',
      'codigo': 'HT-0156',
      'cantidad': 8,
      'lugarResguardo': 'Almacén Central',
      'fecha': '07/11/2024',
    },
  ];

  @override
  void initState() {
    super.initState();
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
    _animationController.dispose();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // Función para filtrar entradas (texto + mes + año)
  List<Map<String, dynamic>> get _entradasFiltradas {
    // Start from the full list or the searched subset
    List<Map<String, dynamic>> lista;
    if (_searchQuery.isEmpty) {
      lista = List<Map<String, dynamic>>.from(_entradas);
    } else {
      lista = _entradas.where((entrada) {
        final herramientaMatch = entrada['herramienta']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final codigoMatch = entrada['codigo'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final lugarMatch = entrada['lugarResguardo']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        return herramientaMatch || codigoMatch || lugarMatch;
      }).toList();
    }

    // Aplicar filtro por mes y año si están seleccionados
    if (_selectedMonth != null) {
      lista = lista.where((entrada) {
        final fecha = entrada['fecha']?.toString() ?? '';
        final parts = fecha.split('/'); // espera dd/mm/yyyy
        if (parts.length < 3) return false;
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (month == null) return false;
        if (_selectedYear != null) {
          return month == _selectedMonth && year == _selectedYear;
        }
        return month == _selectedMonth;
      }).toList();
    }

    return lista;
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showNewEntryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _buildNewEntryModal();
      },
    );
  }

  // Mostrar dialogo para seleccionar mes (filtro)
  void _showMonthFilterDialog() {
    // Mostrar una lista más agradable como modal bottom sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // rango de años para elegir
        final currentYear = DateTime.now().year;
        final years = List<int>.generate(
          6,
          (i) => currentYear - 3 + i,
        ); // current-3 .. current+2

        int? tempMonth = _selectedMonth;
        int? tempYear = _selectedYear;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return SafeArea(
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con título, selector de año y acciones
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filtrar por mes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Selector de año
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: tempYear,
                              hint: const Text('Año'),
                              underline: const SizedBox.shrink(),
                              items: years.map((y) {
                                return DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(y.toString()),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempYear = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedMonth = null;
                                _selectedYear = null;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Limpiar'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedMonth = tempMonth;
                                _selectedYear = tempYear;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Aplicar'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Lista de meses
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _monthNames.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final monthValue = index + 1;
                          final selected = tempMonth == monthValue;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              _monthNames[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.black
                                    : Colors.grey[800],
                              ),
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF16A34A),
                                  )
                                : null,
                            onTap: () {
                              setStateDialog(() {
                                tempMonth = monthValue;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
                  ..setEntry(3, 2, 0.001) // perspectiva
                  ..translateByVector3(Vector3(_slideAnimation.value, 0.0, 0.0)) // solo X
                  ..rotateY(_rotationAnimation.value) // primero rotación
                  ..scaleByVector3(Vector3(_scaleAnimation.value, _scaleAnimation.value, 1.0)), // después escala
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
              ),

              // Overlay cuando el drawer está abierto
              if (_isDrawerOpen)
                Positioned(
                  left: 320,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _closeDrawer,
                    child: Container(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.05),
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
                      border: Border.all(color: Colors.grey[700]!, width: 3),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
                        Navigator.of(context).pop();
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.inventory,
                    title: 'Inventario',
                    isActive: false,
                    onTap: () {
                      _closeDrawer();
                      Future.delayed(const Duration(milliseconds: 350), () {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                      });
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.arrow_downward,
                    title: 'Entradas',
                    isActive: true,
                    onTap: () {
                      _closeDrawer();
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
                          const SnackBar(
                            content: Text('Asignaciones - Próximamente'),
                          ),
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
                          const SnackBar(
                            content: Text('Devoluciones - Próximamente'),
                          ),
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
                          const SnackBar(
                            content: Text('Reposiciones - Próximamente'),
                          ),
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
                          const SnackBar(
                            content: Text('Reportes - Próximamente'),
                          ),
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
                          const SnackBar(
                            content: Text('Administración - Próximamente'),
                          ),
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
                  final navigator = Navigator.of(context);
                  Future.delayed(const Duration(milliseconds: 350), () {
                    navigator.pushNamedAndRemoveUntil('/', (route) => false);
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
          icon: const Icon(Icons.menu, color: Colors.black),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Entradas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'Registro de nuevas herramientas',
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila de acciones: filtro por mes (izq) y nueva entrada (der)
            Row(
              children: [
                // Botón de filtro por mes (izquierda) - diseño personalizado
                SizedBox(
                  width: 160,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showMonthFilterDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.filter_list,
                                color: Color(0xFF16A34A),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedMonth == null
                                    ? 'Filtrar'
                                    : _monthNames[_selectedMonth! - 1],
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedMonth != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMonth = null;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Botón Nueva Entrada (derecha) - same width as filter
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: _showNewEntryModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Nueva Entrada',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Buscador
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por herramienta, código o ubicación...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[500],
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            // Tabla de entradas
            Expanded(
              child: OrientationBuilder(
                builder: (context, orientation) {
                  if (orientation == Orientation.portrait) {
                    // Modo vertical: solo tarjetas sin cabecera
                    return _buildVerticalLayout();
                  } else {
                    // Modo horizontal: cabecera + tabla
                    // Ajustar para usar el ancho disponible (sin scroll horizontal)
                    return Padding(
                      // Añadir un pequeño padding a la derecha para evitar overflow por unos pocos píxeles
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            // Cabecera de tabla horizontal
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'HERRAMIENTA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'CÓDIGO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      'CANT.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'LUGAR RESGUARDO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'FECHA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      'ACCIONES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Lista horizontal
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _buildHorizontalLayout(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para modo horizontal (tabla tradicional)
  Widget _buildHorizontalLayout() {
    return ListView.builder(
      controller: _horizontalScrollController,
      padding: const EdgeInsets.all(0),
      itemCount: _entradasFiltradas.length,
      itemBuilder: (context, index) {
        final entrada = _entradasFiltradas[index];
        return _buildEntryRow(entrada, index);
      },
    );
  }

  // Método para modo vertical (diseño 2x5)
  Widget _buildVerticalLayout() {
    return ListView.builder(
      controller: _verticalScrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _entradasFiltradas.length,
      itemBuilder: (context, index) {
        final entrada = _entradasFiltradas[index];
        return _buildVerticalCard(entrada, index);
      },
    );
  }

  // Fila horizontal tradicional
  Widget _buildEntryRow(Map<String, dynamic> entrada, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entrada['herramienta'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entrada['codigo'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              entrada['cantidad'].toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entrada['lugarResguardo'] ?? 'N/A',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entrada['fecha'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Edit button
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Find real index in the backing list
                      final realIndex = _entradas.indexOf(entrada);
                      if (realIndex >= 0) {
                        _showEditEntryModal(entrada, realIndex);
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Editar',
                    color: Colors.grey[800],
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    alignment: Alignment.center,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text('¿Deseas eliminar esta entrada?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  final realIndex = _entradas.indexOf(entrada);
                                  if (realIndex >= 0) {
                                    _entradas.removeAt(realIndex);
                                  }
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: const Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Eliminar',
                    color: Colors.red,
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    alignment: Alignment.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta vertical con diseño 2x5
  Widget _buildVerticalCard(Map<String, dynamic> entrada, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(1.5)},
        border: TableBorder.all(color: Colors.grey[200]!, width: 1),
        children: [
          // Fila 1: Herramienta
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[50]),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'HERRAMIENTA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  entrada['herramienta'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          // Fila 2: Código
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'CÓDIGO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entrada['codigo'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22C55E),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Fila 3: Cantidad
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[50]),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'CANTIDAD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      entrada['cantidad'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Fila 4: Lugar de resguardo
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'LUGAR RESGUARDO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.place, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entrada['lugarResguardo'] ?? '',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Fila 5: Fecha
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[50]),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'FECHA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      entrada['fecha'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Fila 6: Acciones (Editar / Eliminar)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'ACCIONES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Edit icon only
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _showEditEntryModal(entrada, index),
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Editar',
                        color: Colors.grey[800],
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        alignment: Alignment.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete icon only
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Confirmación antes de eliminar
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmar eliminación'),
                              content: const Text(
                                '¿Deseas eliminar esta entrada?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _entradas.removeAt(index);
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                  child: const Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Eliminar',
                        color: Colors.red,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewEntryModal() {
    final TextEditingController herramientaController = TextEditingController();
    final TextEditingController codigoController = TextEditingController();
    final TextEditingController cantidadController = TextEditingController();
    final TextEditingController lugarController = TextEditingController();
    final TextEditingController fechaController = TextEditingController(
      text: _formatDate(DateTime.now()), // Fecha actual en formato dd/mm/yyyy
    );

    // Variables para controlar los errores de validación
    ValueNotifier<String?> herramientaError = ValueNotifier<String?>(null);
    ValueNotifier<String?> codigoError = ValueNotifier<String?>(null);
    ValueNotifier<String?> cantidadError = ValueNotifier<String?>(null);
    ValueNotifier<String?> lugarError = ValueNotifier<String?>(null);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                  'Nueva Entrada',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Formulario
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo Herramienta
                  const Text(
                    'Nombre de la Herramienta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: herramientaError,
                    builder: (context, error, child) {
                      return TextField(
                        controller: herramientaController,
                        onChanged: (value) {
                          if (value.isNotEmpty && error != null) {
                            herramientaError.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej: Taladro Makita',
                          errorText: error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo Código
                  const Text(
                    'Código',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: codigoError,
                    builder: (context, error, child) {
                      return TextField(
                        controller: codigoController,
                        onChanged: (value) {
                          if (value.isNotEmpty && error != null) {
                            codigoError.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej: HT-0024',
                          errorText: error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo Cantidad
                  const Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: cantidadError,
                    builder: (context, error, child) {
                      return TextField(
                        controller: cantidadController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (value.isNotEmpty && error != null) {
                            cantidadError.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '0',
                          errorText: error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo Lugar de Resguardo
                  const Text(
                    'Lugar de Resguardo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: lugarError,
                    builder: (context, error, child) {
                      return TextField(
                        controller: lugarController,
                        onChanged: (value) {
                          if (value.isNotEmpty && error != null) {
                            lugarError.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej: Almacén Central, Bodega 1, Taller A',
                          errorText: error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: error != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo Fecha (solo lectura)
                  const Text(
                    'Fecha de Entrada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fechaController,
                    readOnly: true,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Fecha automática',
                      suffixIcon: Icon(
                        Icons.lock_outlined,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      fillColor: Colors.grey[100],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
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
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Validar campos individualmente
                      bool hasErrors = false;

                      if (herramientaController.text.isEmpty) {
                        herramientaError.value = 'Este campo es requerido';
                        hasErrors = true;
                      }

                      if (codigoController.text.isEmpty) {
                        codigoError.value = 'Este campo es requerido';
                        hasErrors = true;
                      }

                      if (cantidadController.text.isEmpty) {
                        cantidadError.value = 'Este campo es requerido';
                        hasErrors = true;
                      }

                      if (lugarController.text.isEmpty) {
                        lugarError.value = 'Este campo es requerido';
                        hasErrors = true;
                      }

                      // Si hay errores, no continuar
                      if (hasErrors) {
                        return;
                      }

                      // Agregar nueva entrada
                      setState(() {
                        _entradas.insert(0, {
                          'herramienta': herramientaController.text,
                          'codigo': codigoController.text,
                          'cantidad':
                              int.tryParse(cantidadController.text) ?? 0,
                          'lugarResguardo': lugarController.text,
                          'fecha': fechaController.text,
                        });
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Entrada agregada exitosamente'),
                          backgroundColor: Color(0xFF22C55E),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Guardar Entrada',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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
  }

  void _showEditEntryModal(Map<String, dynamic> entrada, int index) {
    final TextEditingController herramientaController = TextEditingController(
      text: entrada['herramienta'],
    );
    final TextEditingController codigoController = TextEditingController(
      text: entrada['codigo'],
    );
    final TextEditingController cantidadController = TextEditingController(
      text: entrada['cantidad'].toString(),
    );
    final TextEditingController lugarController = TextEditingController(
      text: entrada['lugarResguardo'],
    );
    final TextEditingController fechaController = TextEditingController(
      text: entrada['fecha'],
    );

    // Variables para controlar los errores de validación
    ValueNotifier<String?> herramientaError = ValueNotifier<String?>(null);
    ValueNotifier<String?> codigoError = ValueNotifier<String?>(null);
    ValueNotifier<String?> cantidadError = ValueNotifier<String?>(null);
    ValueNotifier<String?> lugarError = ValueNotifier<String?>(null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Editar Entrada',
                      style: TextStyle(
                        fontSize: 24,
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
              // Formulario
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nombre de la Herramienta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: herramientaError,
                        builder: (context, error, child) {
                          return TextField(
                            controller: herramientaController,
                            onChanged: (value) {
                              if (value.isNotEmpty && error != null) {
                                herramientaError.value = null;
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Ej: Taladro Makita',
                              errorText: error,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: error != null
                                      ? Colors.red
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Código',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: codigoError,
                        builder: (context, error, child) {
                          return TextField(
                            controller: codigoController,
                            onChanged: (value) {
                              if (value.isNotEmpty && error != null) {
                                codigoError.value = null;
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Ej: HT-0024',
                              errorText: error,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: error != null
                                      ? Colors.red
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Cantidad',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: cantidadError,
                        builder: (context, error, child) {
                          return TextField(
                            controller: cantidadController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              if (value.isNotEmpty && error != null) {
                                cantidadError.value = null;
                              }
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              errorText: error,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: error != null
                                      ? Colors.red
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Lugar de Resguardo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: lugarError,
                        builder: (context, error, child) {
                          return TextField(
                            controller: lugarController,
                            onChanged: (value) {
                              if (value.isNotEmpty && error != null) {
                                lugarError.value = null;
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Ej: Almacén Central',
                              errorText: error,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: error != null
                                      ? Colors.red
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Fecha de Entrada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fechaController,
                        readOnly: true,
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Fecha automática',
                          suffixIcon: Icon(
                            Icons.lock_outlined,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          fillColor: Colors.grey[100],
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              // Botones
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          bool hasErrors = false;
                          if (herramientaController.text.isEmpty) {
                            herramientaError.value = 'Este campo es requerido';
                            hasErrors = true;
                          }
                          if (codigoController.text.isEmpty) {
                            codigoError.value = 'Este campo es requerido';
                            hasErrors = true;
                          }
                          if (cantidadController.text.isEmpty) {
                            cantidadError.value = 'Este campo es requerido';
                            hasErrors = true;
                          }
                          if (lugarController.text.isEmpty) {
                            lugarError.value = 'Este campo es requerido';
                            hasErrors = true;
                          }
                          if (hasErrors) return;

                          setState(() {
                            _entradas[index] = {
                              'herramienta': herramientaController.text,
                              'codigo': codigoController.text,
                              'cantidad':
                                  int.tryParse(cantidadController.text) ?? 0,
                              'lugarResguardo': lugarController.text,
                              'fecha': fechaController.text,
                            };
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Entrada actualizada'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
          onTap: onTap,
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
