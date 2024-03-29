import "package:easy_cse/constant/app_string.dart";
import "package:easy_cse/constant/app_style/app_style.dart";
import "package:easy_cse/gui/widget/buttons/jump_button.dart";
import "package:easy_cse/gui/widget/chat_item.dart";
import "package:easy_cse/gui/widget/config/floating_location.dart";
import "package:easy_cse/service/file_manager/image_manger.dart";
import "package:easy_cse/service/provider/chat_state_prov.dart";
import "package:easy_cse/service/provider/prov_manager.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../constant/app_style/app_color.dart";
import "../../service/network/chat_bot.dart";
import "../widget/chat_input_box.dart";
import "../widget/empty_chat_widget.dart";

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<StatefulWidget> createState() =>_ChatPageState();
}

class _ChatPageState extends State<ChatPage>{

  final queryController = TextEditingController();
  final recordController = ScrollController();

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(recordController.hasClients) {
        recordController.jumpTo(
          recordController.position.maxScrollExtent,
        );
      }
    });
  }
  @override
  void dispose(){
    queryController.dispose();
    recordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(
            AppStrings.aiTutor,
            style:AppStyles.iconTextStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        surfaceTintColor: AppColors.discoBallBlue,
        centerTitle: true,
        toolbarHeight: 50,
      ),
      body: Column(
        children: [
          Expanded(
            child: Selector<ChatStateProv, bool>(
              selector: (context, prov)=> prov.chatRecords.isEmpty,
              builder: (context, isEmpty, child)=>isEmpty?
              const EmptyChatWidget():
              Align(
                alignment: Alignment.topCenter,
                child: NotificationListener<ScrollEndNotification>(
                  // 不使用ScrollController::addListener,使用外层包裹的NotificationListener, ScrollEndNotification是用户停止滑动的时候触发
                  onNotification: onNotification,
                  child: Selector<ChatStateProv, int>(
                    selector: (context, prov)=> prov.chatRecords.length,
                    builder: (context, len, child)=>ListView.builder(
                        controller: recordController,
                        // key: ValueKey<int>(len), no need to use key here
                        itemBuilder: (BuildContext context, int index) {
                          return ChatItem(
                            recordIndex: index,
                            key: ValueKey<int>(index),
                            /*说到底ObjectKey也就是检查runtimeType和hashCode,
                      而默认的hashcode就是比较内存地址，也不会多智能，倒不如
                      使用index作为ValueKey,只要保证chatRecords不做修改，
                      就不对因为flutter的element复用机制导致ui出错
                      * */
                          );
                        },
                        itemCount: len,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        reverse: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Selector<ChatStateProv, bool>(
            selector: (context, prov) => prov.waitForAnswer,
            builder: (context, loading, child)=>
            loading?const CircularProgressIndicator(
              color: AppColors.silentBlue,
            ):const SizedBox(),
          ),
          ChatInputBox(
            controller: queryController,
            onCameraClicked: pickImage,
            onSendClicked: onSend,
            onCancelClicked: onCancel,
            buttonColor: AppColors.silentBlue,
            getIfWaiting: ()=>ProvManager.chatStateProv.waitForAnswer,
          ),
        ],
      ),
      floatingActionButton:Selector<ChatStateProv, bool>(
        selector: (context, prov) => prov.showJumpButton,
        builder: (context, show, child)=>
        show?getJumpButton(context, up: false, func: jumpToBottom):const SizedBox(),
      ),
      floatingActionButtonLocation: CustomizeFloatingLocation(
        baseLocation: FloatingActionButtonLocation.endFloat,
        offsetY: -50,
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
  void onSend() async{
    if(queryController.text.isEmpty)return;
    final cprov=ProvManager.chatStateProv;
    cprov.addUserRecord(queryController.text);
    queryController.clear();
    String? answer=await ChatBot.getAnswer(queryController.text);
    answer??=AppStrings.defaultChatBotErrorAnswer;
    cprov.addModelRecord(answer);
    // 现在的效果是粗糙的，有数据到来就滚动到底部，后续可以更加精细，比如当向上滑动超过多少像素时，显示一个按钮，点击按钮后才滚动到底部
    jumpToBottom();
  }
  void pickImage() async{
    await ImageManager.imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50
    ).then((value) {}
    );
  }
  void jumpToBottom(){
    recordController.animateTo(
      recordController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
    );
  }
  bool onNotification(ScrollEndNotification notification){
    int bear=600;
    // 这里的逻辑是当向上滑动超过100像素时，显示一个按钮，点击按钮后才滚动到底部
    // pixels是当前滚动的位置，maxScrollExtent是最大滚动位置
    if(notification.metrics.pixels<notification.metrics.maxScrollExtent-bear){
      ProvManager.chatStateProv.showJumpButton=true;
    }else{
      ProvManager.chatStateProv.showJumpButton=false;
    }
    return false;// 返回true表示消费了这个事件，不再向上传递
  }
  void onCancel(){
    ChatBot.cancelQuery();
  }
}