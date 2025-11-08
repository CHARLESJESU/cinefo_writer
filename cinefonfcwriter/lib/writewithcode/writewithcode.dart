import 'dart:convert';
import 'package:cinefonfcwriter/assets/variables.dart';
import 'package:cinefonfcwriter/writewithcode/2ndscreen.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:http/http.dart' as http;

class WritewithCode extends StatefulWidget {
  const WritewithCode({super.key});

  @override
  State<WritewithCode> createState() => _WritewithCodeState();
}

class _WritewithCodeState extends State<WritewithCode> {
  bool isloading = false;
  TextEditingController codecontroller = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  PhoneNumber number = PhoneNumber(isoCode: 'IN');

  Future<void> submitmobilenumber() async {
    setState(() {
      isloading = true;
    });

    final url =
        Uri.parse('https://vgate.vframework.in/vgateapi/processRequest');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'VMETID':
            'fuGURHGN7HaA6uD2/1B2GDY8zwHFdiygEGPXnWkqT6RDLMJ+1UD6kOgZTZSsXp2qqhIZrjZLrn/SjEVz05DQ+4V+g0KxugsC7vLDQFJMld2cQXEBUy6CcGY8DAGcfDch66twtNpRokDGPgxsXWUAthLTu+daKm4qpR1hGHJhOLe6A9Zp4LnfFDD7Hyr9t++munXW2uRExPH6ORfor4WSozQD9UVjpWRNavY+/dEG7onPqDrWreUBI0mkFHS2v9zVU7G1Y2QRTpqhJBS2iqlC4mhYDYp0TikAydFZ6QbRREhfqjkv4C5gmmPXdO2KT0C53Wuzx3PYiY0tGqNMw8BMoA=='
      },
      body: jsonEncode(<String, dynamic>{
        "number": _mobileController.text,
        "code": codecontroller.text
      }),
    );

    if (response.statusCode == 200) {
      print(response.body);
      setState(() {
        responsedata = json.decode(response.body);
        isloading = false;
      });
      responseDatavcid = responsedata!['responseData'];
      if (responsedata!['statusdescription'] == "Success") {
         writewithcodevcid = responseDatavcid!['vcid'];
        print("VCID: $writewithcodevcid");
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => VCID()));
      } else {
        print("Error: ${responsedata!['statusdescription']}");
      }
    } else {
      setState(() {
        responsedata = json.decode(response.body);
        isloading = false;
      });
      print("Failed to fetch data: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 100),
              Text(
                'Enter Mobile Number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  print(number.phoneNumber);
                },
                initialValue: number,
                textFieldController: _mobileController,
                formatInput: false,
                selectorConfig: SelectorConfig(
                  selectorType: PhoneInputSelectorType.DIALOG,
                ),
                inputDecoration: InputDecoration(
                  hintText: 'Enter your mobile number',
                  labelText: 'Mobile Number',
                  labelStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.lightBlue.shade50,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Enter Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextFormField(
                decoration: InputDecoration(),
                controller: codecontroller,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  submitmobilenumber();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  elevation: 5,
                ),
                child: Center(
                  child: isloading
                      ? CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
