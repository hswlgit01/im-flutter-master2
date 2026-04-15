import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

class ChatMergeView extends StatelessWidget {
  const ChatMergeView({super.key, required this.message});

  final Message message;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Styles.c_E8EAEF,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(message.mergeElem?.title ?? "", 
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Divider(
            height: 1,
            color: Styles.c_E8EAEF,
          ),
          const SizedBox(height: 3,),
          if (message.mergeElem?.multiMessage != null)
            ...List.generate(min(message.mergeElem!.multiMessage!.length, 3), (index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Text( "${message.mergeElem?.multiMessage?[index].senderNickname}: ${IMUtils.parseMsg(message.mergeElem!.multiMessage![index])}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Styles.c_8E9AB0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              );
            }),
        ],
      ),
    );
  }
}