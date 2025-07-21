import Employee from "../model/employee.model.js";
import Department from "../model/department.model.js";
import LeaveTypes from "../model/leaveTypes.model.js";
import Company from "../model/company.model.js";
import EmployeeLeave from "../model/employeeLeave.model.js";
import EmployeeLeaveBalance from "../model/employeeLeaveBalance.model.js";
import OdPass from "../model/odPass.model.js";
// import Attendance from "../model/attendance.model.js";

Employee.hasMany(EmployeeLeave, {
  foreignKey: 'em_id',
  sourceKey: 'em_id'
});

Employee.hasMany(EmployeeLeaveBalance, {
  foreignKey: 'emp_id',
  sourceKey: 'em_id'
});

Employee.belongsTo(Department, {
  foreignKey: 'dep_id',
  targetKey: 'id'
});

Employee.belongsTo(Company, {
  foreignKey: 'comp_id',
  targetKey: 'company_id'
});

LeaveTypes.hasMany(EmployeeLeave, {
  foreignKey: 'typeid',
  sourceKey: 'type_id',
  as: "leaveType"
});

EmployeeLeave.belongsTo(LeaveTypes, {
  foreignKey: 'typeid',
  targetKey: 'type_id',
  as: "leaveTypeInfo"
});

EmployeeLeaveBalance.belongsTo(LeaveTypes, {
  foreignKey: 'leave_type_id',
  targetKey: 'type_id',
  as: 'leave_type',
});

LeaveTypes.hasMany(EmployeeLeaveBalance, {
  foreignKey: 'leave_type_id',
  sourceKey: 'type_id',
});

OdPass.belongsTo(Employee, {
  foreignKey: 'emp_id',
  targetKey: 'em_id'
});
// Attendance.belongsTo(EmployeeLeave,{
//   foreignKey: 'leave_id',
//   targetKey: 'id'
// })

// EmployeeLeave.hasMany(Attendance, {
//   foreignKey: 'leave_id',
//   sourceKey: 'id'
// })


export {
    Employee,
    Department,
    LeaveTypes,
    Company,
    EmployeeLeave,
    EmployeeLeaveBalance
}