import 'package:flutter/material.dart';
import '../models/note_block.dart';
import '../theme/notas_colors.dart';

IconData iconForBlockType(BlockType type) {
  switch (type) {
    case BlockType.heading1:
    case BlockType.heading2:
    case BlockType.heading3:
      return Icons.title_rounded;
    case BlockType.todo:
      return Icons.check_box_outlined;
    case BlockType.bulletList:
      return Icons.format_list_bulleted_rounded;
    case BlockType.numberedList:
      return Icons.format_list_numbered_rounded;
    case BlockType.toggle:
      return Icons.arrow_right_rounded;
    case BlockType.callout:
      return Icons.lightbulb_outline_rounded;
    case BlockType.divider:
      return Icons.horizontal_rule_rounded;
    case BlockType.paragraph:
      return Icons.notes_rounded;
  }
}

List<PopupMenuEntry<BlockType>> buildBlockTypeMenuItems() {
  return [
    _buildMenuItem(BlockType.paragraph, 'Párrafo de texto', Icons.notes_rounded),
    _buildMenuItem(BlockType.heading1, 'Título Grande H1', Icons.title_rounded),
    _buildMenuItem(BlockType.heading2, 'Título Mediano H2', Icons.format_size_rounded),
    _buildMenuItem(BlockType.heading3, 'Título Pequeño H3', Icons.text_fields_rounded),
    _buildMenuItem(BlockType.todo, 'Tarea checklist', Icons.check_box_outlined),
    _buildMenuItem(BlockType.bulletList, 'Lista con viñetas', Icons.format_list_bulleted_rounded),
    _buildMenuItem(BlockType.numberedList, 'Lista numerada', Icons.format_list_numbered_rounded),
    _buildMenuItem(BlockType.toggle, 'Desplegable', Icons.arrow_right_rounded),
    _buildMenuItem(BlockType.callout, 'Destacado Callout', Icons.lightbulb_outline_rounded),
    _buildMenuItem(BlockType.divider, 'Separador de línea', Icons.horizontal_rule_rounded),
  ];
}

PopupMenuItem<BlockType> _buildMenuItem(BlockType type, String title, IconData icon) {
  return PopupMenuItem(
    value: type,
    child: Row(
      children: [
        Icon(icon, size: 18, color: NotasColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class NoteBlockWidget extends StatelessWidget {
  final NoteBlock block;
  final bool isEditable;
  final int index;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final void Function(bool checked)? onToggleTodo;
  final void Function(String newContent)? onContentChanged;
  final void Function()? onDelete;
  final void Function(BlockType newType)? onTypeChanged;
  final void Function()? onAddBlockBelow;
  final void Function(BlockType newType)? onAddBlockBelowWithType;
  final void Function()? onEnterPressed;

  // Callbacks para elementos hijos dentro de desplegables (Toggle)
  final void Function(int childIndex, String content)? onToggleChildContentChanged;
  final void Function(int childIndex, bool checked)? onToggleChildTodo;
  final void Function(int childIndex, BlockType type)? onToggleChildTypeChanged;
  final void Function(int childIndex)? onToggleChildDelete;
  final void Function(int childIndex, BlockType type)? onToggleChildAddBelow;
  final void Function(int childIndex)? onToggleChildEnter;
  final FocusNode Function(String childId, VoidCallback? onEnter)? getChildFocusNode;
  final TextEditingController Function(String childId, String content)? getChildController;

  const NoteBlockWidget({
    super.key,
    required this.block,
    this.isEditable = false,
    this.index = 0,
    this.controller,
    this.focusNode,
    this.onToggleTodo,
    this.onContentChanged,
    this.onDelete,
    this.onTypeChanged,
    this.onAddBlockBelow,
    this.onAddBlockBelowWithType,
    this.onEnterPressed,
    this.onToggleChildContentChanged,
    this.onToggleChildTodo,
    this.onToggleChildTypeChanged,
    this.onToggleChildDelete,
    this.onToggleChildAddBelow,
    this.onToggleChildEnter,
    this.getChildFocusNode,
    this.getChildController,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case BlockType.heading1:
        return _buildHeading(fontSize: 22, fontWeight: FontWeight.w900);
      case BlockType.heading2:
        return _buildHeading(fontSize: 18, fontWeight: FontWeight.w800);
      case BlockType.heading3:
        return _buildHeading(fontSize: 15, fontWeight: FontWeight.w700);
      case BlockType.todo:
        return _buildTodo(context);
      case BlockType.bulletList:
        return _buildBullet();
      case BlockType.numberedList:
        return _buildNumbered();
      case BlockType.toggle:
        return _ToggleBlockView(
          block: block,
          isEditable: isEditable,
          controller: controller,
          focusNode: focusNode,
          onContentChanged: onContentChanged,
          onDelete: onDelete,
          onTypeChanged: onTypeChanged,
          onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
          onEnterPressed: onEnterPressed,
          onToggleChildContentChanged: onToggleChildContentChanged,
          onToggleChildTodo: onToggleChildTodo,
          onToggleChildTypeChanged: onToggleChildTypeChanged,
          onToggleChildDelete: onToggleChildDelete,
          onToggleChildAddBelow: onToggleChildAddBelow,
          onToggleChildEnter: onToggleChildEnter,
          getChildFocusNode: getChildFocusNode,
          getChildController: getChildController,
        );
      case BlockType.callout:
        return _buildCallout(context);
      case BlockType.divider:
        return _buildDivider();
      case BlockType.paragraph:
        return _buildParagraph();
    }
  }

  Widget _buildHeading({required double fontSize, required FontWeight fontWeight}) {
    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(
          block.content,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: NotasColors.textPrimary,
            height: 1.3,
          ),
        ),
      );
    }
    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        initialValue: controller == null ? block.content : null,
        onChanged: (val) {
          if (val.contains('\n')) {
            final cleaned = val.replaceAll('\n', '');
            if (controller != null) controller!.text = cleaned;
            onContentChanged?.call(cleaned);
            onEnterPressed?.call();
          } else {
            onContentChanged?.call(val);
          }
        },
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => onEnterPressed?.call(),
        maxLines: 1,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: NotasColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Encabezado...',
          hintStyle: TextStyle(fontSize: fontSize, color: NotasColors.textMuted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    );
  }

  Widget _buildParagraph() {
    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          block.content,
          style: const TextStyle(
            fontSize: 14,
            color: NotasColors.textPrimary,
            height: 1.5,
          ),
        ),
      );
    }
    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        initialValue: controller == null ? block.content : null,
        onChanged: onContentChanged,
        maxLines: null,
        style: const TextStyle(fontSize: 14, color: NotasColors.textPrimary, height: 1.4),
        decoration: const InputDecoration(
          hintText: 'Escribe algo...',
          hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  Widget _buildTodo(BuildContext context) {
    final isChecked = block.isChecked;
    final checkbox = GestureDetector(
      onTap: () => onToggleTodo?.call(!isChecked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 10, top: 2),
        decoration: BoxDecoration(
          color: isChecked ? NotasColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isChecked ? NotasColors.primary : NotasColors.textMuted,
            width: 1.8,
          ),
        ),
        alignment: Alignment.center,
        child: isChecked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );

    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkbox,
            Expanded(
              child: GestureDetector(
                onTap: () => onToggleTodo?.call(!isChecked),
                child: Text(
                  block.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isChecked ? NotasColors.textMuted : NotasColors.textPrimary,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    decorationColor: NotasColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          checkbox,
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              initialValue: controller == null ? block.content : null,
              onChanged: (val) {
                if (val.contains('\n')) {
                  final cleaned = val.replaceAll('\n', '');
                  if (controller != null) controller!.text = cleaned;
                  onContentChanged?.call(cleaned);
                  onEnterPressed?.call();
                } else {
                  onContentChanged?.call(val);
                }
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onEnterPressed?.call(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                color: isChecked ? NotasColors.textMuted : NotasColors.textPrimary,
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
              decoration: const InputDecoration(
                hintText: 'Tarea pendiente...',
                hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet() {
    const bullet = Padding(
      padding: EdgeInsets.only(right: 10, top: 7),
      child: Icon(Icons.circle, size: 6, color: NotasColors.primary),
    );

    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bullet,
            Expanded(
              child: Text(
                block.content,
                style: const TextStyle(fontSize: 14, color: NotasColors.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bullet,
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              initialValue: controller == null ? block.content : null,
              onChanged: (val) {
                if (val.contains('\n')) {
                  final cleaned = val.replaceAll('\n', '');
                  if (controller != null) controller!.text = cleaned;
                  onContentChanged?.call(cleaned);
                  onEnterPressed?.call();
                } else {
                  onContentChanged?.call(val);
                }
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onEnterPressed?.call(),
              maxLines: 1,
              style: const TextStyle(fontSize: 14, color: NotasColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Elemento de lista...',
                hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumbered() {
    final prefix = Padding(
      padding: const EdgeInsets.only(right: 8, top: 1),
      child: Text(
        '${index + 1}.',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: NotasColors.primary,
        ),
      ),
    );

    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prefix,
            Expanded(
              child: Text(
                block.content,
                style: const TextStyle(fontSize: 14, color: NotasColors.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prefix,
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              initialValue: controller == null ? block.content : null,
              onChanged: (val) {
                if (val.contains('\n')) {
                  final cleaned = val.replaceAll('\n', '');
                  if (controller != null) controller!.text = cleaned;
                  onContentChanged?.call(cleaned);
                  onEnterPressed?.call();
                } else {
                  onContentChanged?.call(val);
                }
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onEnterPressed?.call(),
              maxLines: 1,
              style: const TextStyle(fontSize: 14, color: NotasColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Paso numerado...',
                hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout(BuildContext context) {
    final icon = block.calloutIcon ?? '💡';
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NotasColors.calloutWarnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NotasColors.calloutWarnBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: !isEditable
                ? Text(
                    block.content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NotasColors.textPrimary,
                      height: 1.4,
                    ),
                  )
                : TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    initialValue: controller == null ? block.content : null,
                    onChanged: onContentChanged,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NotasColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Acuerdo destacado o nota importante...',
                      hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
          ),
        ],
      ),
    );

    if (!isEditable) return card;
    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: card,
    );
  }

  Widget _buildDivider() {
    final line = Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: const Divider(height: 1, thickness: 1.2, color: NotasColors.cardBorder),
    );
    if (!isEditable) return line;
    return _EditableBlockContainer(
      block: block,
      onDelete: onDelete,
      onTypeChanged: onTypeChanged,
      onAddBlockBelowWithType: onAddBlockBelowWithType ?? (onAddBlockBelow != null ? (_) => onAddBlockBelow!() : null),
      child: line,
    );
  }
}

class _ToggleBlockView extends StatefulWidget {
  final NoteBlock block;
  final bool isEditable;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final void Function(String content)? onContentChanged;
  final void Function()? onDelete;
  final void Function(BlockType newType)? onTypeChanged;
  final void Function(BlockType newType)? onAddBlockBelowWithType;
  final void Function()? onEnterPressed;

  // Handlers para hijos dentro del desplegable
  final void Function(int childIndex, String content)? onToggleChildContentChanged;
  final void Function(int childIndex, bool checked)? onToggleChildTodo;
  final void Function(int childIndex, BlockType type)? onToggleChildTypeChanged;
  final void Function(int childIndex)? onToggleChildDelete;
  final void Function(int childIndex, BlockType type)? onToggleChildAddBelow;
  final void Function(int childIndex)? onToggleChildEnter;
  final FocusNode Function(String childId, VoidCallback? onEnter)? getChildFocusNode;
  final TextEditingController Function(String childId, String content)? getChildController;

  const _ToggleBlockView({
    required this.block,
    required this.isEditable,
    this.controller,
    this.focusNode,
    this.onContentChanged,
    this.onDelete,
    this.onTypeChanged,
    this.onAddBlockBelowWithType,
    this.onEnterPressed,
    this.onToggleChildContentChanged,
    this.onToggleChildTodo,
    this.onToggleChildTypeChanged,
    this.onToggleChildDelete,
    this.onToggleChildAddBelow,
    this.onToggleChildEnter,
    this.getChildFocusNode,
    this.getChildController,
  });

  @override
  State<_ToggleBlockView> createState() => _ToggleBlockViewState();
}

class _ToggleBlockViewState extends State<_ToggleBlockView> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Por defecto abierto al editar o si ya tiene elementos hijos
    _isExpanded = widget.isEditable || widget.block.children.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final toggleHeaderTitle = Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedRotation(
            turns: _isExpanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.arrow_right_rounded, size: 22, color: NotasColors.primary),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: !widget.isEditable
              ? GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(
                    widget.block.content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NotasColors.textPrimary,
                    ),
                  ),
                )
              : TextFormField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  initialValue: widget.controller == null ? widget.block.content : null,
                  onChanged: (val) {
                    if (val.contains('\n')) {
                      final cleaned = val.replaceAll('\n', '');
                      if (widget.controller != null) widget.controller!.text = cleaned;
                      widget.onContentChanged?.call(cleaned);
                      setState(() => _isExpanded = true);
                      widget.onEnterPressed?.call();
                    } else {
                      widget.onContentChanged?.call(val);
                    }
                  },
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    setState(() => _isExpanded = true);
                    widget.onEnterPressed?.call();
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NotasColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Título de la sección desplegable...',
                    hintStyle: TextStyle(fontSize: 14, color: NotasColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
        ),
      ],
    );

    final headerRow = widget.isEditable
        ? _EditableBlockContainer(
            block: widget.block,
            onDelete: widget.onDelete,
            onTypeChanged: widget.onTypeChanged,
            onAddBlockBelowWithType: widget.onAddBlockBelowWithType,
            child: toggleHeaderTitle,
          )
        : toggleHeaderTitle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow,
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(left: 30, top: 2),
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(widget.block.children.length, (childIdx) {
                    final childBlock = widget.block.children[childIdx];
                    final childNode = widget.getChildFocusNode?.call(
                      childBlock.id,
                      () => widget.onToggleChildEnter?.call(childIdx),
                    );
                    final childCtrl = widget.getChildController?.call(
                      childBlock.id,
                      childBlock.content,
                    );

                    return NoteBlockWidget(
                      key: ValueKey(childBlock.id),
                      block: childBlock,
                      index: childIdx,
                      isEditable: widget.isEditable,
                      controller: childCtrl,
                      focusNode: childNode,
                      onContentChanged: (c) => widget.onToggleChildContentChanged?.call(childIdx, c),
                      onToggleTodo: (chk) => widget.onToggleChildTodo?.call(childIdx, chk),
                      onTypeChanged: (t) => widget.onToggleChildTypeChanged?.call(childIdx, t),
                      onDelete: () => widget.onToggleChildDelete?.call(childIdx),
                      onAddBlockBelowWithType: (t) => widget.onToggleChildAddBelow?.call(childIdx, t),
                      onEnterPressed: () => widget.onToggleChildEnter?.call(childIdx),
                    );
                  }),
                  if (widget.isEditable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: PopupMenuButton<BlockType>(
                        tooltip: 'Agregar elemento al desplegable',
                        onSelected: (type) {
                          setState(() => _isExpanded = true);
                          widget.onToggleChildAddBelow?.call(widget.block.children.length - 1, type);
                        },
                        itemBuilder: (ctx) => buildBlockTypeMenuItems(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: NotasColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 13, color: NotasColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Agregar dentro',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: NotasColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _EditableBlockContainer extends StatelessWidget {
  final NoteBlock block;
  final Widget child;
  final void Function()? onDelete;
  final void Function(BlockType newType)? onTypeChanged;
  final void Function(BlockType newType)? onAddBlockBelowWithType;

  const _EditableBlockContainer({
    required this.block,
    required this.child,
    this.onDelete,
    this.onTypeChanged,
    this.onAddBlockBelowWithType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda con el botón selector de tipo y el botón (+) pequeño redondo debajo
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PopupMenuButton<BlockType>(
                tooltip: 'Cambiar tipo de bloque',
                icon: Icon(
                  iconForBlockType(block.type),
                  size: 16,
                  color: NotasColors.textMuted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onSelected: onTypeChanged,
                itemBuilder: (context) => buildBlockTypeMenuItems(),
              ),
              if (onAddBlockBelowWithType != null) ...[
                const SizedBox(height: 2),
                PopupMenuButton<BlockType>(
                  tooltip: 'Agregar bloque abajo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  onSelected: onAddBlockBelowWithType,
                  itemBuilder: (context) => buildBlockTypeMenuItems(),
                  offset: const Offset(24, 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 15, color: NotasColors.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDelete,
              tooltip: 'Eliminar bloque',
            ),
        ],
      ),
    );
  }
}
