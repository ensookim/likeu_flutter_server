import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_likeu/extensions/space_exs.dart';
import 'package:flutter_likeu/views/camera/components/custom_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  final ImagePicker _picker = ImagePicker();
  List<List<dynamic>> _csvData = []; // CSV 데이터를 저장할 리스트

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CSV Data")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          60.h,
          SizedBox(
            height: 500,
            child: Center(
              child: Container(
                width: double.infinity,
                height: 500,
                alignment: Alignment.center,
                margin: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: _csvData.isEmpty
                    ? const Text("Selected Video", textAlign: TextAlign.center)
                    : ListView.builder(
                        itemCount: _csvData.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text('Frame: ${_csvData[index][0]}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Keypoints: ${_csvData[index][1]}'),
                                Text('Elbow Angle: ${_csvData[index][2]}'),
                                Text('Knee Angle: ${_csvData[index][3]}'),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          _openGalleryOrCameraButtonLoader(),
        ],
      ),
    );
  }

  Widget _openGalleryOrCameraButtonLoader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomButton(
          function: () {
            log('open gallery');
            _pickVideoFromGallery();
          },
          buttonName: 'Gallery',
        ),
        20.w,
        CustomButton(
          function: () {
            log("open camera");
          },
          buttonName: 'Camera',
        ),
      ],
    );
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        log('선택한 비디오 경로: ${video.path}');
        await requestVideoToFlask(video.path);
      } else {
        log('선택한 비디오가 없음');
      }
    } catch (e) {
      log('비디오 선택 중 오류 발생: $e');
    }
  }

  Future<void> requestVideoToFlask(String videoPath) async {
    const String serverUrl = 'http://192.168.25.14:3000/upload'; // Flask 엔드포인트

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('video', videoPath));

      var response = await request.send();

      if (response.statusCode == 200) {
        // CSV 파일 저장
        final bytes = await response.stream.toBytes();
        final directory = await getApplicationDocumentsDirectory();
        final csvFile = File('${directory.path}/output.csv');
        await csvFile.writeAsBytes(bytes);

        // CSV 파일 경로 로그 출력
        log('CSV 파일 저장 경로: ${csvFile.path}');

        // CSV 파일 내용 읽기
        List<List<dynamic>> csvContent = await _readCsvFile(csvFile);
        setState(() {
          _csvData = csvContent;
        });
      } else {
        log('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      log('Flask에 비디오 전송 중 오류 발생: $e');
    }
  }

  Future<List<List<dynamic>>> _readCsvFile(File file) async {
    final contents = await file.readAsString();
    List<List<dynamic>> rows = const CsvToListConverter().convert(contents);

    // keypoints 문자열을 읽어와서 변환
    for (var i = 1; i < rows.length; i++) {
      // 첫 번째 줄은 헤더이므로 1부터 시작
      String keypointsStr = rows[i][1].toString();
      keypointsStr = keypointsStr
          .replaceAll('np.float32(', '')
          .replaceAll(')', '')
          .replaceAll(' ', ''); // 불필요한 공백 제거

      rows[i][1] = keypointsStr; // 변환된 keypoints 문자열을 넣습니다.
    }

    return rows;
  }
}
