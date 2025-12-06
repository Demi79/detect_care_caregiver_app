import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SixDigitInputField extends StatefulWidget {
  final void Function(String) onCompleted;
  const SixDigitInputField({super.key, required this.onCompleted});

  @override
  State<SixDigitInputField> createState() => _SixDigitInputFieldState();
}

class _SixDigitInputFieldState extends State<SixDigitInputField> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _textFieldFocusNodes = List.generate(6, (_) => FocusNode());
  final _keyboardFocusNodes = List.generate(6, (_) => FocusNode());
  static const double _spacing = 12.0;

  @override
  void initState() {
    super.initState();
    // Khi xóa, nếu ô trống thì backspace nhảy về ô trước
    for (var i = 0; i < 6; i++) {
      _textFieldFocusNodes[i].addListener(() {
        if (_textFieldFocusNodes[i].hasFocus) {
          _controllers[i].selection = TextSelection.collapsed(
            offset: _controllers[i].text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _textFieldFocusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const totalSpacing = _spacing * 5;
        final boxSize = (constraints.maxWidth - totalSpacing) / 6;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            return Container(
              width: boxSize,
              height: boxSize,
              margin: EdgeInsets.only(right: i < 5 ? _spacing : 0),
              child: KeyboardListener(
                focusNode: _keyboardFocusNodes[i],
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    if (_controllers[i].text.isEmpty && i > 0) {
                      FocusScope.of(
                        context,
                      ).requestFocus(_textFieldFocusNodes[i - 1]);
                      _controllers[i - 1].text = '';
                    }
                  }
                },
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _textFieldFocusNodes[i],
                  autofocus: i == 0,
                  textAlign: TextAlign.center,
                  obscureText: true,
                  obscuringCharacter: '•',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: i < 5
                      ? TextInputAction.next
                      : TextInputAction.done,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    // Nếu người dùng paste 6 số vào bất kỳ ô nào
                    if (value.length == 6 &&
                        RegExp(r'^[0-9]{6}$').hasMatch(value)) {
                      for (int j = 0; j < 6; j++) {
                        _controllers[j].text = value[j];
                      }
                      FocusScope.of(context).unfocus();
                      widget.onCompleted(value);
                      return;
                    }
                    final code = _controllers.map((c) => c.text).join();
                    widget.onCompleted(code);
                    if (value.length == 1) {
                      // tự động nhảy sang ô tiếp theo
                      if (i < 5) {
                        FocusScope.of(
                          context,
                        ).requestFocus(_textFieldFocusNodes[i + 1]);
                      } else {
                        FocusScope.of(context).unfocus();
                      }
                    }
                  },
                  onSubmitted: (_) {
                    // Nếu bấm nút "Done" trên keyboard của ô cuối
                    if (i == 5) {
                      final code = _controllers.map((c) => c.text).join();
                      if (code.length == 6) widget.onCompleted(code);
                    }
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
