import Attendance from "../model/attendance.model.js";
import { DateTime } from "luxon";
import { Employee } from "../utils/join.js";
import MonitorData from "../model/monitorData.model.js";
import { Op } from "sequelize";

const punchAttendance = async(req, res) => {
    try {
        const { emp_id, comp_id, punchtype, punch_place, punch_remark, punch_img, latitude, longitude, created_by } = req.body;

       const istNow = DateTime.now().setZone('Asia/Kolkata');
       const punchDate = istNow.toISODate(); 
       const punchTime = istNow.toFormat('HH:mm:ss'); 
       const createdAtIst = istNow.toISO();
       
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
        }

        let warning = null;
        if (punchtype === 'OUTSTATION1') {
            if (lastPunchIn && !punchOutExists) {
                warning = "Warning: You did not punch out last time. Proceeding with new punch in.";
                console.log("Warning",warning);
            }
        }

        const employee = await Employee.findOne({ where: { em_id: emp_id } });
      if (!employee || !employee.attcode) {
            return res.status(404).json({ message: "Employee not found or missing attcode" });
        }

        const enrollId = employee.attcode;
        console.log("Enroll ID:", enrollId);

        const newAttendance = await Attendance.create({
            emp_id,
            comp_id,
            punch_date: punchDate,
            punch_time: punchTime,
            punch_place,
            punchtype,
            punch_remark,
            punch_img,
            latitude,
            longitude,
            created_by,
            created_at: createdAtIst
        });

        const monitorData = await MonitorData.create({
            SRNO: newAttendance.punchtype,
            EnrollID: enrollId,
            PunchDate: newAttendance.punch_date,
            Received_date: newAttendance.punch_date,
            verifyMode: 'Selfie'
        });

        console.log("Attendance recorded:", newAttendance,);
        console.log("Monitor Data recorded:", monitorData,);

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

const getAttendance = async (req, res) => {
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


const getPunchDurations = async (req, res) => {
  const { empId } = req.params;

  try {
    const punchIns = await Attendance.findAll({
      where: { emp_id: empId, punchtype: 'OUTSTATION1' },
      order: [['punch_date', 'DESC'], ['punch_time', 'DESC']],
    });

    // console.log("punchIns",punchIns);

    const sessions = [];

    for (const punchIn of punchIns) {
      const punchOut = await Attendance.findOne({
        where: {
          emp_id: empId,
          punchtype: 'OUTSTATION2',
          punch_date: {
            [Op.gte]: punchIn.punch_date
          },
          punch_time: {
            [Op.gt]: punchIn.punch_time
          }
        },
        order: [['punch_date', 'ASC'], ['punch_time', 'ASC']]
      });

      console.log("punchOut",punchOut);
      if (!punchOut) continue; 

      const punchInDateTime = DateTime.fromISO(`${punchIn.punch_date}T${punchIn.punch_time}`);
      const punchOutDateTime = DateTime.fromISO(`${punchOut.punch_date}T${punchOut.punch_time}`);

      const duration = punchOutDateTime.diff(punchInDateTime, ['hours', 'minutes']);

      sessions.push({
        punch_in: `${punchIn.punch_date} ${punchIn.punch_time}`,
        punch_out: `${punchOut.punch_date} ${punchOut.punch_time}`,
        duration: `${duration.hours}h ${duration.minutes}m`
      });
    }

    console.log("sessions",sessions);

    res.status(200).json(sessions, { message: 'Punch durations fetched successfully' });

  } catch (error) {
    res.status(500).json({ message: 'Error fetching punch durations', error: error.message });
  }
};


export {
    punchAttendance,
    getAttendance,
    getPunchDurations
}