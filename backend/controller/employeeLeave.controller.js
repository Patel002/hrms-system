import { EmployeeLeave, Employee, LeaveTypes, Company, EmployeeLeaveBalance } from "../utils/join.js";
import { uploadOnCloudinary } from "../utils/cloudinary.js";
import { Op } from "sequelize";
import { DateTime } from "luxon";
import fs from "fs";

const MAX_FILE_SIZE_MB = 10;

const createLeave = async (req, res) => {
    const {
        em_id,
        leave_type,
        comp_fname,
        start_date,
        end_date,
        apply_date,
        leave_duration,
        reason
    } = req.body;

    console.log("Request Body:", req.body);

    let attachment = null;
    let day_type = "";

    const istNow = DateTime.now().setZone('Asia/Kolkata');
    const createdAtIst = istNow.toJSDate();


    // const leaveattachment = req.file ? req.file.filename : null;
    // if (!leaveattachment) {
    //     return res.status(400).json({ message: "Leave attachment is required" });
    // }
    // console.log("Leave Attachment:", leaveattachment);
    // console.log("Request Body:", req.body);

    try {
  
    const duration = parseFloat(leave_duration);
    if (isNaN(duration) || !(duration === 0.5 || duration >= 1)) {
        return res.status(400).json({
            message: "Leave duration must be at least 1 day or exactly 0.5 for half-day leave.",
        });
    }

    if(duration === 0.5){
      day_type = "Half-Day";
    }else if(duration === 1){
      day_type = "Full-Day";
    }else if(duration > 1){
      day_type = "More Than One Day";
    }else{
      return res.status(400).json({ message: "Invalid leave duration" });
    }

        const employee = await Employee.findOne({ where: { em_id } });
        if (!employee) {
            return res.status(404).json({ message: "Employee not found" });
        }
        const employeeId = employee.em_id;
        console.log("Employee ID:", employee.em_id);

        const leaveType = await LeaveTypes.findOne({ where: { name: req.body.leave_type } });
        if (!leaveType) return res.status(400).json({ message: "Invalid leave type" });

        // console.log("Leave Type ID:", leaveType.type_id);
        // console.log("Leave Type Name:", leaveType.name);

        const company = await Company.findOne({ where: { comp_fname } });
        if (!company) {
            return res.status(404).json({ message: "Company not found" });
        }

        const isSingleDayLeave = start_date === end_date;
        console.log("isSingleDayLeave",isSingleDayLeave);

        if(isSingleDayLeave && parseFloat(leave_duration) === 0.5){

          const existingHalfLeave = await EmployeeLeave.findAll({
            where: {
              em_id: employeeId,
              start_date: start_date,
              end_date: end_date,
              leave_status: {
                [Op.in]: ["Approve", "Not Approve"]
              }
            }
          });

          console.log("existingHalfLeave",existingHalfLeave);

          let totalDuration = 0;
          let fullDayCount = 0;
          let halfDayCount = 0;
          // let sameTypeHalfDayLeaveExist = false; 

          existingHalfLeave.forEach((leave) => {
            
            const duration = parseFloat(leave.leave_duration);
            totalDuration += duration;

            if (duration === 1) fullDayCount++;
            if (duration === 0.5) halfDayCount++;

            // if(duration === 0.5 && leave.leave_type === leave_type){
            //   sameTypeHalfDayLeaveExist = true;
            // }

          });

          console.log("totalDuration",totalDuration);

        // if (totalDuration + 0.5 > 1 || sameTypeHalfDayLeaveExist) {
        // let message = "You have already applied for leave on this date.";
        if (totalDuration + 0.5 > 1) {
        let message = "You have already applied for leave on this date.";

        if (fullDayCount >= 1) {
          message = "You have already applied for leave in this period of date.";
        // } else if (sameTypeHalfDayLeaveExist) {
        //   message = `You have already applied for half day leave of ${leave_type} on this date.`;
        } else if (halfDayCount >= 1) {
          message = "You have already applied for half day leave on this date.";
        }

        return res.status(400).json({ message });
      }
        }else {
        const isLeaveExistsWithSameDate = await EmployeeLeave.findOne({
          where: {
            em_id: employeeId,
            [Op.or]: [
              {
                start_date: {
                  [Op.between]: [start_date, end_date]
                },
              },
              {
                end_date: {
                  [Op.between]: [start_date, end_date]
                },
              },
              {
                start_date: {
                  [Op.lte]: start_date,
                },
                end_date: {
                  [Op.gte]: end_date,
                },
              },
            ],
            leave_status: {
              [Op.in]: ["Approve", "Not Approve"]
            }
          },
        })
        if(isLeaveExistsWithSameDate){
            return res.status(400).json({ message: "You have already applied for leave in this period of date" });
        }
        console.log("isLeaveExistsWithSameDate",isLeaveExistsWithSameDate);
      }

        
       if (leaveType.name !== "Leave Without Pay") {
        const credit = await EmployeeLeaveBalance.sum('number_of_days', {
            where: {
              emp_id: employeeId,
              leave_type_id: leaveType.type_id,
              leave_status: "Credit"
            }
          });

          console.log("Credit:", credit);

        if (credit === null) {
        return res.status(400).json({
            message: `No credit found for this leave type.`
        });
       }
          const debit = await EmployeeLeaveBalance.sum('number_of_days', {
            where: {
              emp_id: employeeId,
              leave_type_id: leaveType.type_id,
              leave_status: "Debit"
            }
          });
          
          const available = (credit || 0) + (debit || 0);
          console.log("Available Leave Days:", available);
          
          if (leave_duration > available) {
            return res.status(400).json({
              message: `Insufficient leave days for ${leave_type}. Remaining leave days: ${available}`
            });
          }
        }

        if(req.file){

        const fileStats = fs.statSync(req.file.path);
        const fileSizeInMB = fileStats.size / (1024 * 1024);

        if (fileSizeInMB > MAX_FILE_SIZE_MB) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({
          message: `Attachment exceeds 10MB limit (${fileSizeInMB.toFixed(2)} MB)`,
        });
      }

        const fileUrl = await uploadOnCloudinary(req.file.path); 
        if (!fileUrl || !fileUrl.url) {
        return res.status(500).json({ message: "Cloudinary upload failed" });
      } 
        attachment = fileUrl;

         console.log("fileUrl",fileUrl); 
      }
       

        const leave = await EmployeeLeave.create({
            em_id: employeeId,
            comp_id: company.comp_id,
            typeid: leaveType.type_id,
            leave_type: day_type,
            start_date,
            end_date,
            leave_duration,
            apply_date,
            reason,
            leave_status: "Not Approve",
            leaveattachment : attachment?.url,
            created_by: employeeId,
            update_id: employeeId,
            update_date: createdAtIst,
            created_at: createdAtIst,
        });

        // console.log("Leave Created:", leave);
        return res.status(201).json({ message: "Leave created successfully", leave });

    } catch (error) {
        console.error("Error creating leave:", error);
        return res.status(500).json({ message: "Server side error" });
    }
} 

// const rejectLeave = async (req, res) => {
//     const { id } = req.params;
//     const { reject_reason } = req.body;

//     try {
//         const leave = await EmployeeLeave.findOne({ where: { id } });
//         if (!leave) {
//             return res.status(404).json({ message: "Leave not found" });
//         }
//         if (leave.leave_status === 'rejected') {
//             return res.status(400).json({ message: "Leave already rejected" });
//         }

//         const result = await leave.update({
//             leave_status: 'rejected',
//             reject_reason: reject_reason || null,
//         });

//         return res.status(200).json({ message: "Leave request rejected", result });

//     } catch (error) {
//         console.log("Error rejecting leave: ", error);
//         res.status(500).json({ message: "Server side error from reject leave", error });
//     }
// }

const getLeavesByStatusForEmployee = async (req, res) => {

    const { em_username, status, leave_type_id } = req.query;
    try {
        const employee = await Employee.findOne({ where: { em_username } });
        if (!employee) {
            return res.status(404).json({ message: "Employee not found" });
        }

          const whereCondition = {
          em_id: employee.em_id,
          leave_status: status,
        };

        console.log("whereCondition",whereCondition);

        if (leave_type_id) {
          whereCondition.typeid = leave_type_id;
        }

        console.log("leaveIdOf",whereCondition.typeid)

        const leaves = await EmployeeLeave.findAll({ 
          where: whereCondition,
          include: [
            {
              model: LeaveTypes,
              as: 'leaveTypeInfo',
              attributes: [
                'type_id',
                'name'
              ]
            }
          ]
        });

        console.log("leave_status",leaves.leave_status);
        console.log("leaves: ", leaves);

        return res.status(200).json({ leaves });

    } catch (error) {
        console.error("Error fetching leaves by status for employee:", error);
        
        return res.status(500).json({ message: "Server error from get leaves by status for employee" });
    }
};

// const getFileAttachment = async(req, res) => {
//     const filename = req.params.filename;   
//     const filePath = path.resolve('..','uploads', filename);

//     fs.access(filePath, fs.constants.F_OK, (err) => {
//         if (err) {
//             res.status(404).send('File not found');
//         } 
//         res.sendFile(filePath);
//     });

// }

const updateLeaveApplication = async(req, res) => {
    const {id} = req.params;
    const updateData = req.body;

    try {
        const leave = await EmployeeLeave.findByPk(id);
        if (!leave) {
            return res.status(404).json({ message: "Leave not found" });
        }
        
        console.log("leave",updateData);

        const updatedLeaveTypeName = updateData.leave_type || leave.leave_type;

        console.log("updatedLeaveTypeName",updatedLeaveTypeName);

        const hasDateChange =
        updateData.start_date ||
        updateData.end_date ||
        updateData.leave_duration ;
        // updateData.leave_type;

        if(hasDateChange){

        let updatedLeaveDuration = updateData.leave_duration || leave.leave_duration;

        updatedLeaveDuration = parseFloat(updatedLeaveDuration);

        if (isNaN(updatedLeaveDuration) || !(updatedLeaveDuration === 0.5 || updatedLeaveDuration >= 1))
            {
            console.log("Invalid input:", updatedLeaveDuration);
            return res.status(400).json({
                message: "Leave duration must be at least 1 day or exactly 0.5 for half-day leave.",
            });
        }

        const updatedStartDate = updateData.start_date || leave.start_date;

        const updatedEndDate = updateData.end_date || leave.end_date;

        console.log("updated start date", updatedStartDate);
        console.log("update end date", updatedEndDate);

        const isSingleDay = updatedStartDate === updatedEndDate;

        if (isSingleDay && updatedLeaveDuration === 0.5) {
        const existingLeaves = await EmployeeLeave.findAll({
          where: {
            em_id: leave.em_id,
            start_date: updatedStartDate,
            end_date: updatedEndDate,
            leave_status: { [Op.in]: ["Approve", "Not Approve"] },
            id: { [Op.ne]: leave.id } 
          }
        });

        let totalDuration = 0;
        let fullDayCount = 0;
        let halfDayCount = 0;
        // let sameTypeHalfDayLeaveExist = false;

        existingLeaves.forEach((existingLeave) => {
          const dur = parseFloat(existingLeave.leave_duration);
          totalDuration += dur;

          if (dur === 1) fullDayCount++;
          if (dur === 0.5) halfDayCount++;
      //     if (dur === 0.5 && existingLeave.leave_type === updatedLeaveTypeName) {
      //   sameTypeHalfDayLeaveExist = true;
      // }
        });

        // if (totalDuration + 0.5 > 1 || sameTypeHalfDayLeaveExist) {
        //   let message = "You have already applied for leave on this date.";
        if (totalDuration + 0.5 > 1) {
          let message = "You have already applied for leave on this date.";
          if (fullDayCount >= 1) {
            message = "You have already applied for leave in this period of date.";
          // } else if (sameTypeHalfDayLeaveExist) {
          //   message = `You have already applied for half day leave of ${updatedLeaveTypeName} on this date.`;
          } else if (halfDayCount >= 1) {
            message = "You have already applied for half day leave on this date.";
          }
          return res.status(400).json({ message });
        }

      } else {
          const overlapping = await EmployeeLeave.findOne({
            where: {
              em_id: leave.em_id,
              leave_status: { [Op.in]: ["Approve", "Not Approve"] },
              id: { [Op.ne]: leave.id },
              [Op.or]: [
                { start_date: { [Op.between]: [updatedStartDate, updatedEndDate] } },
                { end_date: { [Op.between]: [updatedStartDate, updatedEndDate] } },
                {
                  start_date: { [Op.lte]: updatedStartDate },
                  end_date: { [Op.gte]: updatedEndDate }
                }
            ]
          }
        });

        if (overlapping) {
          return res.status(400).json({ message: "You have already applied for leave in this period of date." });
        }
      }
    }

        const leaveType = await LeaveTypes.findOne({ where: { name: updatedLeaveTypeName } });
        if (!leaveType) {
            return res.status(400).json({ message: "Invalid leave type" });
        }

        if (updateData.leave_type) {
            updateData.typeid = leaveType.type_id;
        }

       if (leaveType.name !== "Leave Without Pay") {
        const credit = await EmployeeLeaveBalance.sum('number_of_days', {
            where: {
              emp_id: leave.em_id,
              leave_type_id: updateData.typeid,
              leave_status: "Credit"
            }
          });

          // console.log("Credit:", credit);

        if (credit === null) {
        return res.status(400).json({
            message: `No credit found for this leave type.`
        });
       }
          
          const debit = await EmployeeLeaveBalance.sum('number_of_days', {
            where: {
              emp_id: leave.em_id,
              leave_type_id: updateData.typeid,
              leave_status: "Debit"
            }
          });

          console.log("Debit:", debit);
          console.log("typeid",updateData.typeid);

          // console.log("Debit:", debit);
          const creditLeave = parseFloat(credit || 0)
          const debitLeave = parseFloat(debit || 0) 

          console.log({
            creditLeave,
            debitLeave
          })
          
          const available = creditLeave + debitLeave;
          console.log("Available Leave Days:", available);
          console.log("Leave Duration:", updateData.leave_duration);

          let availableLeave = parseFloat(available);
          console.log("availableLeave",availableLeave);

          let updatedLeaveDuration = parseFloat(updateData.leave_duration || leave.leave_duration);

          console.log("Updated Leave Duration:", updatedLeaveDuration);
          
          if (updatedLeaveDuration > available) {
        return res.status(400).json({
          message: `Insufficient leave days for ${leaveType.name}. Remaining leave days: ${available}`
        });
      }
}
        if(req.file){
          const result = await uploadOnCloudinary(req.file.path);
          if(result && result.secure_url){
            updateData.leaveattachment = result.secure_url;
            console.log("updated attachment",updateData.leaveattachment);
          }
          
        }
        updateData.update_date = new Date();
       

        updateData.update_id = leave.em_id;
        console.log("updated id",updateData.update_id);

        const updateResult = await leave.update(updateData);

        console.log("Leave application updated successfully",updateResult);

        res.status(201).json({ message: 'Leave application updated successfully', data: leave });

        
    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: "Server error while upadating leave application" });
    }
}

const getLeaveRequestsBySupervisor = async (req, res) => {
  const { status } = req.params;
  const { em_id, em_role } = req.user;

  try {
    if (em_role === 'SUPER ADMIN') {
      const allLeaveRequests = await EmployeeLeave.findAll({
        where: { leave_status: status },
      });
      return res.status(200).json({
        pendingLeaves: allLeaveRequests,
      });
    }

    const subordinates = await Employee.findAll({
      where: { supervisor_id: (em_id) },
    });

    console.log(subordinates);

    const subordinateIds = subordinates.map(emp => emp.em_id);
    console.log("subordinateIds:", subordinateIds);

    if (subordinateIds.length === 0) {
      return res.status(200).json([
        {
          message: 'No leave requests found',
        },
      ]); 
    }

    const leaveRequests = await EmployeeLeave.findAll({
      where: { em_id: subordinateIds,leave_status: status },
    });

    res.status(200).json({
        pendingLeaves: leaveRequests
    });
  } catch (err) {
    console.error('Error fetching leave requests:', err);
    res.status(500).json({ error: 'Failed to get leave requests' });
  }
};

const approveRejectLeave = async(req, res) => {
const { id } = req.params;
const { action, reject_reason } = req.body;
try {
    const leave = await EmployeeLeave.findOne({ where: { id } });
    if (!leave) {
        return res.status(404).json({ message: "Leave not found" });
    }

    const employee = await Employee.findOne({ where: { em_code: leave.em_id } });

    if (!employee || employee.supervisor_id !== req.user.em_code && req.user.em_role !== 'SUPER ADMIN') {
        return res.status(403).json({ message: "You are not authorized to approve/reject this leave" });
    }

    // console.log("leave_type_id",leave.typeid,"employee.em_id",employee.em_id,"quattro",req.user.em_role);

    if (action === "approve") {

     if (leave.typeid !== 20) {

    if (employee.typeid !== 20) {
        const credit = await EmployeeLeaveBalance.sum('number_of_days', {
        where: {
          emp_id: employee.em_id,
          leave_type_id: leave.typeid,
          leave_status: "Credit"
        }
      });

      // console.log("Credit:", credit);

      if (credit === null) {
        return res.status(400).json({
            message: `No credit found for this leave type.`
        });
    }
    
      const debit = await EmployeeLeaveBalance.sum('number_of_days', {
        where: {
          emp_id: employee.em_id,
          leave_type_id: leave.typeid,
          leave_status: "Debit"
        }
      });
      
        // console.log("Debit:", debit);

        const availableBalance = (credit || 0) + (debit || 0);
        // console.log("Available Leave Days:", availableBalance);

        if (leave.leave_duration > availableBalance) {
        return res.status(400).json({
            message: `Insufficient leave days for ${leave.leave_type}. Remaining leave days: ${availableBalance}`
        });
    }            
            const balanceCreate = await EmployeeLeaveBalance.create({
                request_id: leave.id,
                comp_id: leave.comp_id,
                emp_id: leave.em_id,
                leave_type_id: leave.typeid,
                number_of_days: -Math.abs(leave.leave_duration),
                add_date: new Date(),
                leave_status: 'Debit',
                leave_upload_date: leave.created_at
            })
            console.log("balanceCreate",balanceCreate);
        }
    }
        leave.leave_status = "Approve";
        leave.reject_reason = `Approved By ${req.user.em_name}`;
        
    }else if (action === "reject") {
        leave.leave_status = "Rejected";
        leave.reject_reason = reject_reason;
    }

    // leave.approved_by = req.user.em_code;
    leave.approved_at = new Date();
    leave.update_date = new Date();
    const result = await leave.save();

    return res.status(200).json({ message: "Leave request updated" ,result});
}
    catch (error) {
        console.log("Error rejecting leave: ", error);
        res.status(500).json({ message: "Server side error from reject leave", error });
    }
}


const getLeaves = async(req, res) => {
    const { em_id, status, date } = req.query;
console.log("em_id",em_id,"status",status,"date",date); 
    try {

      let checkLeave = {
        em_id,
      }

      if(status){
        checkLeave.leave_status = status
      }

      if(date){
        checkLeave = {
          ...checkLeave,
          start_date: { [Op.lte]: date },
          end_date: { [Op.gte]: date }
        }
         const leaves = await EmployeeLeave.findAll({ where: checkLeave });

      console.log("leaves: ", leaves);  
      return res.status(200).json({ leaves });
    
    }

    const leaves = await EmployeeLeave.findAll({ where: checkLeave });
    const calendarLeaves = {};

    leaves.forEach(leave => {
      const fromDate = new Date(leave.start_date);
      const toDate = new Date(leave.end_date);

      for (let d = new Date(fromDate); d <= toDate; d.setDate(d.getDate() + 1)) {
      const dateKey = d.toISOString().split('T')[0];

    if (!calendarLeaves[dateKey]) {
          calendarLeaves[dateKey] = [];
        }

        calendarLeaves[dateKey].push({
          leaveId: leave.id,
          leaveTypeId: leave.typeid,
          leaveType: leave.leave_type,
          leaveStatus: leave.status,
          isHalfDay: leave.leave_duration === '0.5', 
        });
      }

    })

    console.log("calendarLeaves: ", calendarLeaves);

    return res.status(200).json({ calendarLeaves });
      
    } catch (error) {
      console.log("Error fetching leaves:", error);
      return res.status(500).json({ message: "Server error while fetching leaves" });
    }

  }

export { createLeave, getLeavesByStatusForEmployee ,updateLeaveApplication,approveRejectLeave,getLeaveRequestsBySupervisor,getLeaves};
