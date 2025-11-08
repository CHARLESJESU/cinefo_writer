import 'package:cinefonfcwriter/readerscreen.dart';
import 'package:cinefonfcwriter/writerscreen.dart';
import 'package:cinefonfcwriter/writewithcode/writewithcode.dart';
import 'package:cinefonfcwriter/writewithvcid/writewithvcid.dart';
import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Cinefonfcwriter'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 30, right: 30, top: 80),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReadWriteNFCScreen(),
                            ));
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 65,
                            width: 80,
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(20)),
                            child: Center(
                                child: Image.asset(
                              'lib/assets/reader.png',
                              height: 30,
                            )),
                          ),
                          Text('Read Tag')
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WriterScreen(),
                            ));
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 65,
                            width: 80,
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(20)),
                            child: Center(
                                child: Image.asset(
                              'lib/assets/writer.png',
                              height: 30,
                            )),
                          ),
                          Text('Write Tag')
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WritewithCode(),
                            ));
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 65,
                            width: 80,
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(20)),
                            child:
                                Center(child: Icon(Icons.wifi_protected_setup)),
                          ),
                          Text('Write with code ')
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WriteVcid(),
                            ));
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 65,
                            width: 80,
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(20)),
                            child:
                                Center(child: Icon(Icons.wifi_protected_setup)),
                          ),
                          Text('Write with Vcid ')
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
