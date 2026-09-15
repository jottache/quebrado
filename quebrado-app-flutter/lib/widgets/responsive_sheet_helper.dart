import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Helper universal para abrir BottomSheets en móvil y Drawer/Side-Sheets en Desktop/Web.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color backgroundColor = Colors.transparent,
  double desktopWidth = 480,
  String? title,
}) {
  final isDesktop = ResponsiveBreakpoints.isDesktop(context);

  if (!isDesktop) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }

  // En Desktop: Abrir como un Drawer / Side Panel deslizante desde la derecha o modal flotante optimizado
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: desktopWidth.clamp(380.0, MediaQuery.of(context).size.width * 0.9),
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 30,
                  offset: Offset(-8, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: Navigator(
                onGenerateRoute: (routeSettings) => MaterialPageRoute(
                  settings: routeSettings,
                  builder: (nestedContext) => builder(nestedContext),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Widget envoltorio para listas con scroll horizontal que en Desktop/Web
/// provee botones interactivos a la izquierda y derecha para deslizarse con un clic.
class ResponsiveHorizontalScroll extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final double scrollStep;
  final EdgeInsetsGeometry padding;

  const ResponsiveHorizontalScroll({
    super.key,
    required this.child,
    this.controller,
    this.scrollStep = 260.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ResponsiveHorizontalScroll> createState() => _ResponsiveHorizontalScrollState();
}

class _ResponsiveHorizontalScrollState extends State<ResponsiveHorizontalScroll> {
  late final ScrollController _scrollController;
  bool _showLeft = false;
  bool _showRight = true;
  bool _hasInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _hasInternalController = true;
    }

    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    if (_hasInternalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    final canScrollLeft = offset > 10;
    final canScrollRight = offset < max - 10;

    if (canScrollLeft != _showLeft || canScrollRight != _showRight) {
      setState(() {
        _showLeft = canScrollLeft;
        _showRight = canScrollRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset - widget.scrollStep).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + widget.scrollStep).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (!isDesktop) {
      return widget.child;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: widget.padding,
          child: widget.child,
        ),
        // Botón Scroll Izquierda
        if (_showLeft)
          Positioned(
            left: 0,
            child: _buildScrollButton(
              icon: Icons.chevron_left_rounded,
              onTap: _scrollLeft,
            ),
          ),
        // Botón Scroll Derecha
        if (_showRight)
          Positioned(
            right: 0,
            child: _buildScrollButton(
              icon: Icons.chevron_right_rounded,
              onTap: _scrollRight,
            ),
          ),
      ],
    );
  }

  Widget _buildScrollButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xFF1F6F5F),
            ),
          ),
        ),
      ),
    );
  }
}
