import Attendance from "../model/attendance.model.js";
import { DateTime } from "luxon";
import { Employee, EmployeeLeave } from "../utils/join.js";
import MonitorData from "../model/monitorData.model.js";
import { Op } from "sequelize";
import holiday from "../model/holiday.model.js";

const punchAttendance = async(req, res) => {
    try {
        const { emp_id, comp_id, punchtype, punch_place, punch_remark, punch_img, latitude, longitude, created_by } = req.body;

       const istNow = DateTime.now().setZone('Asia/Kolkata');
       const punchDate = istNow.toISODate(); 
       const punchTime = istNow.toJSDate(); 
       const createdAtIst = istNow.toJSDate();
       
           console.log("Current IST Date and Time:", istNow);
           console.log("Punch Date:", punchDate);
           console.log("Punch Time:", punchTime);
           console.log("Created At:", createdAtIst);

        if (!emp_id || !comp_id || !punch_place || !punch_img || !latitude || !longitude || !created_by) {
            return res.status(400).json({ message: "All fields are required" });
        }

        const lastPunchIn = await Attendance.findOne({
            where: {
                emp_id,
                punchtype: 'OUTSTATION1'
            },
            order: [['created_at', 'DESC']]
        });

        const punchOutExists = lastPunchIn
            ? await Attendance.findOne({
                where: {
                    emp_id,
                    punchtype: 'OUTSTATION2',
                    created_at: { [Op.gt]: lastPunchIn.created_at }
                }
            })
            : null;

        if (punchtype === 'OUTSTATION2') {
            if (!lastPunchIn) {
                return res.status(400).json({ message: "Cannot punch out without any previous punch in." });
            }
            if (punchOutExists) {
                return res.status(400).json({ message: "You have already punched out for your last punch in." });
            }

            let lastInTime;
            if (typeof lastPunchIn.created_at === 'string') {
            lastInTime = DateTime.fromSQL(lastPunchIn.created_at, { zone: 'utc' }).setZone('Asia/Kolkata');

            } else {
             lastInTime = DateTime.fromJSDate(lastPunchIn.created_at, { zone: 'utc' }).setZone('Asia/Kolkata');

            }

            // console.log("last in time",lastInTime)
            // console.log("typeof last in time",typeof lastInTime)

            if (!lastInTime.isValid) {
            console.error("Invalid lastInTime:", lastInTime.invalidExplanation);
            return res.status(500).json({ message: "Internal error: Invalid punch in time format" });
            }


            const diffTime = istNow.diff(lastInTime,'minutes').minutes;
            console.log("diffrance time", diffTime)

            if(diffTime < 30){
                return res.status(400).json({ message: `Cannot punch out within 30 minutes of punch in. Try again after ${Math.ceil(30 - diffTime)} minutes.` });
            }
        }
        
        let updatePunchRemark = punch_remark;
        let warning = null;

        if (punchtype === 'OUTSTATION1') {
            if (lastPunchIn && !punchOutExists) {

                    // warning = "Warning: You did not punch out last time. Proceeding with new punch in.";

                 updatePunchRemark = (punch_remark || '') + " (Last Punch Out Missing)";

                console.log("Warning",warning);
            }
        }

        const employee = await Employee.findOne({ where: { em_id: emp_id } });
      if (!employee || !employee.attcode) {
            return res.status(404).json({ message: "Employee not found or missing attcode" });
        }

        const enrollId = employee.attcode;
        // console.log("Enroll ID:", enrollId);

        const newAttendance = await Attendance.create({
            emp_id,
            comp_id,
            punch_date: punchDate,
            punch_time: punchTime,
            punch_place,
            punchtype,
            punch_remark: updatePunchRemark,
            punch_img,
            latitude,
            longitude,
            created_by,
            created_at: createdAtIst
        });

        const monitorData = await MonitorData.create({
            SRNO: newAttendance.punchtype,
            EnrollID: enrollId,
            PunchDate: punchTime,
            Received_date: punchTime,
            verifyMode: 'Selfie',
            // Temperature_c: 0,
            // TRID: 0,
            // Temperature_f: 0
        });

        // console.log("Attendance recorded:", newAttendance,);
        // console.log("Monitor Data recorded:", monitorData,);

        res.status(201).json({
            message: "Attendance recorded successfully",
            warning: warning,
            data: newAttendance,
            monitorData
        });

    } catch (error) {
        console.error("Error recording attendance:", error);
        res.status(500).json({
            message: "Error recording attendance",
            error: error.message
        });
    }
}

const getAttendance = async(req, res) => {
    const { emp_id, punch_date } = req.query;
    if (!emp_id) {
        return res.status(400).json({ message: "Employee ID is required" });
    }
    try {
        const attendances = await Attendance.findAll({
            where: {
                emp_id: emp_id,
                punch_date: punch_date
            }
        });
        res.status(200).json({ message: "Attendances fetched successfully", data: attendances });
    } catch (error) {
        console.error("Error fetching attendances:", error);
        res.status(500).json({
            message: "Error fetching attendances",
            error: error.message
        });
    }
}


const getPunchDurations = async(req, res) => {
  const { empId } = req.params;

  try {
    const punchIns = await Attendance.findAll({
      where: { emp_id: empId, punchtype: 'OUTSTATION1' },
      order: [['created_at', 'ASC']],
    });

    // console.log('punch in date', punchIns.punch_time);

    const punchOuts = await Attendance.findAll({
      where: { emp_id: empId, punchtype: 'OUTSTATION2' },
      order: [['created_at', 'ASC']],
    });

    const sessions = [];
    const usedPunchIns = new Set();

    for (const punchOut of punchOuts) {
      const punchOutTime = DateTime.fromISO(punchOut.created_at.replace(' ', 'T'));

      let matchedIndex = -1;
      let matchedPunchInTime = null;

    //  console.log('match punch in time', matchedPunchInTime);

     punchIns.forEach((punchIn, index) => {
    const punchInTime = DateTime.fromISO(punchIn.created_at.replace(' ', 'T'));

    if (punchInTime < punchOutTime && !usedPunchIns.has(index)) {
      if (!matchedPunchInTime || punchInTime > matchedPunchInTime) {
        matchedPunchInTime = punchInTime;
        matchedIndex = index;
      }
    }
  });

       if (matchedIndex === -1) continue;

        const punchIn = punchIns[matchedIndex];
        const duration = punchOutTime.diff(matchedPunchInTime, ['hours', 'minutes']);

        sessions.push({
        punch_in: `${punchIn.punch_date} ${punchIn.punch_time}`,
        punch_out: `${punchOut.punch_date} ${punchOut.punch_time}`,
        duration: `${duration.hours}h ${duration.minutes}m`
    });

      usedPunchIns.add(matchedIndex);;
    }

    return res.status(200).json({
      message: 'Punch durations fetched successfully',
      data: sessions
    });


  } catch (error) {
    res.status(500).json({ message: 'Error fetching punch durations', error: error.message });
  }
};


const getAttendanceSummary = async(req, res) => {
    const { empId } = req.params;
    const { month, year } = req.query;

    try {
        const employee = await Employee.findOne({
            where: { em_id: empId },
            attributes: ['em_joining_date']
        })

        if (!employee) return res.status(404).json({ message: 'Employee not found' });

        const joiningDate = DateTime.fromISO(employee.em_joining_date);
        const startDate = DateTime.local(+year, +month, 1);
        const endDate = startDate.endOf('month');
        const effectiveStart = joiningDate > startDate ? joiningDate : startDate;

        const holidays = await holiday.findAll({
            where: {
                [Op.or]: [
                    {
                        from_date: {
                            [Op.between]: [
                                effectiveStart.toISODate(),
                                endDate.toISODate()
                            ]
                        },
                    },
                      {
                          to_date: {
                            [Op.between]: [
                                effectiveStart.toISODate(),
                                endDate.toISODate()
                            ]
                        },
                    },
                    {
                        from_date: {
                            [Op.lte]: effectiveStart.toISODate()
                        },
                        to_date: {
                            [Op.gte]: endDate.toISODate()
                        }
                    }
                ]
            },
            attributes: ['from_date', 'to_date']
        });

        const holidayDates = new Set();

        for (const holiday of holidays) {
        let from = DateTime.fromISO(holiday.from_date);
        let to = DateTime.fromISO(holiday.to_date);
        for (let d = from; d <= to; d = d.plus({ days: 1 })) {
            if (d >= effectiveStart && d <= endDate) {
            holidayDates.add(d.toISODate());
            }
        }
     }


        const leaves = await EmployeeLeave.findAll({
            where: {
             em_id: empId,
             leave_status: 'Approve',
             [Op.or]: [
                {
                    start_date: {
                        [Op.between]: [
                            effectiveStart.toISODate(),
                            endDate.toISODate()
                        ]
                    },
                },
                {
                    end_date: {
                        [Op.between]: [
                            effectiveStart.toISODate(),
                            endDate.toISODate()
                        ]
                    },
                },
                {
                    start_date: {
                        [Op.lte]: effectiveStart.toISODate()
                    },
                    end_date: {
                        [Op.gte]: endDate.toISODate()
                    }
                }
             ]
            },
            attributes: ['start_date', 'end_date']
        });

        // console.log("leaves: ", leaves); 

        const leaveDates = new Set();
        for (const leave of leaves) {
        let from = DateTime.fromISO(leave.start_date);
        let to = DateTime.fromISO(leave.end_date);
        for (let d = from; d <= to; d = d.plus({ days: 1 })) {
            if (d >= effectiveStart && d <= endDate) {
            leaveDates.add(d.toISODate());
            }
        }
        }

    const workingDays = [];
    for (let d = effectiveStart; d <= endDate; d = d.plus({ days: 1 })) {
      const isWeekend = [7].includes(d.weekday); 
      const isHoliday = holidayDates.has(d.toISODate());
      if (!isWeekend && !isHoliday) {
        workingDays.push(d.toISODate());
      }
    }

        const attendance = await Attendance.findAll({
        where: {
            emp_id: empId,
            punch_date: {
            [Op.between]: [effectiveStart.toISODate(), endDate.toISODate()]
            }
        },
        attributes: ['punch_date'],
        group: ['punch_date']
        });

        console.log("Attendance: ", attendance);

        const presentDates = new Set(attendance.map(a => a.punch_date));

        const presentCount = presentDates.size;
        const totalWorking = workingDays.length;
        const approvedLeaveCount = [...workingDays].filter(d => leaveDates.has(d)).length;
        const absentCount = [...workingDays].filter(d => !presentDates.has(d) && !leaveDates.has(d)).length;

        res.status(200).json({
        message: 'Attendance summary fetched successfully',
        data: {
            totalWorkingDays: totalWorking,
            present: presentCount,
            approvedLeave: approvedLeaveCount,
            absent: absentCount,
            holidays: holidayDates.size,
            month: `${year}-${month.padStart?.(2, '0') || String(month).padStart(2, '0')}`
        }
        });

    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: "Internal Server Error From Getting Attendance Summary" });
    }
}


export {
    punchAttendance,
    getAttendance,
    getPunchDurations,
    getAttendanceSummary
}