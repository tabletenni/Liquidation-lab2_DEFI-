# include <iostream>
# include "Student.h"

using namespace std;

class Teacher{
private:
    string name;

public:
    Teacher(string);
    string getName();
    void giveScore(Student, double);
    void giveScore(Student*, double);
    // overloding -> มีชื่อเดียวกันเเต่พาลามิเตอร์ต่างกันได้ 
    // overriding
};