import localUnitTest from './LocalUnit.test';
import teacherUnitTest from './TeacherUnit.test';

export default function testsuite() {
  localUnitTest();
  teacherUnitTest();
}