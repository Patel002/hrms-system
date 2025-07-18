import { Sequelize } from 'sequelize';
import {
  EmployeeLeaveBalance,
  LeaveTypes
} from '../utils/join.js';


const getEmployeeLeaveBalance = async (req, res) => {
  const { em_code } = req.params;

  try {
    const balances = await EmployeeLeaveBalance.findAll({
      where: { emp_id: em_code },
      attributes: [
        'leave_type_id',
        [Sequelize.fn('SUM', Sequelize.literal(`CASE WHEN LOWER(leave_status) = 'credit' THEN number_of_days ELSE 0 END`)), 'credit'],
        [Sequelize.fn('SUM', Sequelize.literal(`CASE WHEN LOWER(leave_status) LIKE 'debit%' THEN ABS(number_of_days)
         ELSE 0 END`)), 'debit']
      ],
      group: ['employee_leave_balance.leave_type_id', 'leave_type.type_id'],
      include: [{
        model: LeaveTypes,
        as: 'leave_type',
        attributes: ['type_id', 'name','leave_short_name']
      }]
    });

  //  console.log(JSON.stringify(balances, null, 2));

    const formatted = balances.map(b => {
      const Credit = parseFloat(b.get('credit')) || 0;
      const debit = parseFloat(b.get('debit')) || 0;

      console.log("credit: ", Credit);
      console.log("debit: ", debit);

      return {
        leave_type_id: b.leave_type_id,
        leave_type_name: b.leave_type.name, 
        leave_short_name: b.leave_type.leave_short_name,
        available_balance: Credit - debit,
        credit: Credit, 
        debit: debit
      };
    });

    return res.status(200).json(formatted);

  } catch (error) {
    console.log(error);
    return res.status(500).json({ message: "Server error from get employee leave balance" });
  }
};

export {
    getEmployeeLeaveBalance
}
