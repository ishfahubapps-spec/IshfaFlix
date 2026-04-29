import '../model/genresmodel.dart';
import '../model/langaugemodel.dart';
import '../model/channelmodel.dart';
import '../model/sectiontypemodel.dart';
import '../utils/utils.dart';
import '../webservice/apiservices.dart';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  SectionTypeModel sectionTypeModel = SectionTypeModel();
  LangaugeModel langaugeModel = LangaugeModel();
  GenresModel genresModel = GenresModel();
  ChannelModel channelModel = ChannelModel();

  bool loading = false;
  int selectedIndex = -1;
  String currentPage = "";

  void notifyProvider() {
    notifyListeners();
  }

  Future<void> getSectionType() async {
    loading = true;
    sectionTypeModel = await ApiService().sectionType();
    printLog("getSectionType status :==> ${sectionTypeModel.status}");
    printLog("getSectionType message :==> ${sectionTypeModel.message}");
    loading = false;
    notifyListeners();
  }

  Future<void> getGenres() async {
    genresModel = await ApiService().genres();
    printLog("getGenres status :===> ${genresModel.status}");
    printLog("getGenres message :==> ${genresModel.message}");
    notifyListeners();
  }

  Future<void> getLanguage() async {
    langaugeModel = await ApiService().language();
    printLog("getLanguage status :===> ${langaugeModel.status}");
    printLog("getLanguage message :==> ${langaugeModel.message}");
    notifyListeners();
  }

  Future<void> getChannel() async {
    channelModel = await ApiService().channel();
    printLog("getChannel status :===> ${channelModel.status}");
    printLog("getChannel message :==> ${channelModel.message}");
    notifyListeners();
  }

  Future<void> setLoading(bool isLoading) async {
    loading = isLoading;
    notifyListeners();
  }

  void setSelectedTab(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void setCurrentPage(String pageName) {
    currentPage = pageName;
    notifyListeners();
  }

  void homeNotifyProvider() {
    notifyListeners();
  }

  void clearProvider() {
    sectionTypeModel = SectionTypeModel();
    langaugeModel = LangaugeModel();
    genresModel = GenresModel();
    channelModel = ChannelModel();
    loading = false;
    selectedIndex = -1;
    currentPage = "";
  }
}
